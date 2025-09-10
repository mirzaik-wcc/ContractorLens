const sharp = require('sharp');

class ARFrameProcessor {
  constructor() {
    this.defaultConfig = {
      maxWidth: 1024,
      maxHeight: 1024,
      quality: 85,
      format: 'jpeg'
    };
  }

  async processFrames(frames, options = {}) {
    const config = { ...this.defaultConfig, ...options };
    const processedFrames = [];

    for (const frame of frames) {
      try {
        const processed = await this.processFrame(frame, config);
        processedFrames.push(processed);
      } catch (error) {
        console.warn(`Failed to process frame ${frame.timestamp}:`, error.message);
        // Include original frame if processing fails
        processedFrames.push(frame);
      }
    }

    return processedFrames;
  }

  async processFrame(frame, config) {
    // Validate frame structure
    if (!frame.imageData || !frame.timestamp) {
      throw new Error('Invalid frame structure: missing imageData or timestamp');
    }

    // If frame is already base64, decode it for processing
    let imageBuffer;
    if (frame.imageData.startsWith('data:image/')) {
      // Data URL format
      const base64Data = frame.imageData.split(',')[1];
      imageBuffer = Buffer.from(base64Data, 'base64');
    } else {
      // Assume it's already base64 encoded
      imageBuffer = Buffer.from(frame.imageData, 'base64');
    }

    // Process with Sharp
    const processedBuffer = await sharp(imageBuffer)
      .resize({
        width: config.maxWidth,
        height: config.maxHeight,
        fit: 'inside',
        withoutEnlargement: true
      })
      .jpeg({ quality: config.quality })
      .toBuffer();

    // Calculate processing metadata
    const originalStats = await sharp(imageBuffer).stats();
    const processedStats = await sharp(processedBuffer).stats();

    return {
      ...frame,
      imageData: processedBuffer.toString('base64'),
      mimeType: `image/${config.format}`,
      processing_metadata: {
        original_size: imageBuffer.length,
        processed_size: processedBuffer.length,
        compression_ratio: (1 - processedBuffer.length / imageBuffer.length).toFixed(3),
        original_channels: originalStats.channels,
        processed_channels: processedStats.channels,
        processed_at: new Date().toISOString()
      }
    };
  }

  optimizeFrameSelection(frames, maxFrames = 10) {
    if (frames.length <= maxFrames) {
      return frames;
    }

    // Sort frames by timestamp to ensure chronological order
    const sortedFrames = frames.sort((a, b) => 
      new Date(a.timestamp) - new Date(b.timestamp)
    );

    // Strategy: Select frames evenly distributed across the scan duration
    const selectedFrames = [];
    const interval = Math.floor(sortedFrames.length / maxFrames);

    for (let i = 0; i < maxFrames; i++) {
      const index = i * interval;
      if (index < sortedFrames.length) {
        selectedFrames.push(sortedFrames[index]);
      }
    }

    // Always include the last frame if it wasn't selected
    const lastFrame = sortedFrames[sortedFrames.length - 1];
    if (!selectedFrames.some(f => f.timestamp === lastFrame.timestamp)) {
      selectedFrames[selectedFrames.length - 1] = lastFrame;
    }

    return selectedFrames;
  }

  enhanceFrameContext(frames) {
    return frames.map((frame, index) => ({
      ...frame,
      sequence_position: index + 1,
      total_frames: frames.length,
      relative_timestamp: this.calculateRelativeTimestamp(frame, frames),
      lighting_score: this.assessLightingQuality(frame),
      blur_score: this.assessBlurLevel(frame)
    }));
  }

  calculateRelativeTimestamp(currentFrame, allFrames) {
    const timestamps = allFrames.map(f => new Date(f.timestamp)).sort((a, b) => a - b);
    const current = new Date(currentFrame.timestamp);
    const start = timestamps[0];
    const end = timestamps[timestamps.length - 1];
    const duration = end - start;
    
    if (duration === 0) return 0;
    
    const elapsed = current - start;
    return (elapsed / duration * 100).toFixed(1); // Percentage through scan
  }

  assessLightingQuality(frame) {
    // Placeholder - in real implementation, you'd analyze the actual image
    // For now, use any provided lighting_conditions or default
    const conditions = frame.lighting_conditions;
    const scoreMap = {
      'excellent': 0.9,
      'good': 0.7,
      'fair': 0.5,
      'poor': 0.3
    };
    
    return scoreMap[conditions] || 0.7; // Default to good
  }

  assessBlurLevel(frame) {
    // Placeholder - in real implementation, you'd calculate blur using image analysis
    // This could use algorithms like Laplacian variance
    // For now, return a default moderate sharpness score
    return 0.7;
  }

  filterHighQualityFrames(frames, qualityThreshold = 0.6) {
    return frames.filter(frame => {
      const lightingScore = this.assessLightingQuality(frame);
      const blurScore = this.assessBlurLevel(frame);
      const averageQuality = (lightingScore + blurScore) / 2;
      
      return averageQuality >= qualityThreshold;
    });
  }

  addTemporalContext(frames) {
    return frames.map((frame, index) => {
      const context = {
        is_first_frame: index === 0,
        is_last_frame: index === frames.length - 1,
        is_middle_frame: index === Math.floor(frames.length / 2)
      };

      // Add scanning phase context
      const scanPhase = this.determineScanPhase(index, frames.length);
      context.scan_phase = scanPhase;

      return {
        ...frame,
        temporal_context: context
      };
    });
  }

  determineScanPhase(index, total) {
    const progress = index / (total - 1);
    
    if (progress < 0.33) return 'initial_survey';
    if (progress < 0.66) return 'detailed_analysis'; 
    return 'final_review';
  }

  async preprocessForGemini(frames, options = {}) {
    console.log(`Starting preprocessing for ${frames.length} frames`);
    
    // Step 1: Optimize frame selection
    const maxFrames = options.maxFrames || 10;
    const selectedFrames = this.optimizeFrameSelection(frames, maxFrames);
    console.log(`Selected ${selectedFrames.length} frames for analysis`);

    // Step 2: Filter for quality if requested
    let qualityFrames = selectedFrames;
    if (options.filterQuality) {
      qualityFrames = this.filterHighQualityFrames(selectedFrames, options.qualityThreshold);
      console.log(`${qualityFrames.length} frames passed quality filter`);
    }

    // Step 3: Process frames (resize, compress, optimize)
    const processedFrames = await this.processFrames(qualityFrames, options.processing);
    
    // Step 4: Add contextual metadata
    const contextualFrames = this.addTemporalContext(
      this.enhanceFrameContext(processedFrames)
    );

    console.log(`Preprocessing complete: ${contextualFrames.length} frames ready for Gemini`);
    
    return contextualFrames;
  }

  // Utility method to calculate total data size
  calculateDataSize(frames) {
    const totalSize = frames.reduce((sum, frame) => {
      const imageSize = frame.imageData ? Buffer.byteLength(frame.imageData, 'base64') : 0;
      return sum + imageSize;
    }, 0);

    return {
      total_bytes: totalSize,
      total_mb: (totalSize / (1024 * 1024)).toFixed(2),
      frames_count: frames.length,
      average_frame_size: Math.round(totalSize / frames.length)
    };
  }
}

module.exports = ARFrameProcessor;
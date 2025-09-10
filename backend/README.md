# ContractorLens Backend

The deterministic Assembly Engine and API backend for ContractorLens construction cost estimation.

## 🏗️ Architecture Overview

This is **NOT** an AI-based estimator. The Assembly Engine performs deterministic calculations using:

1. **Structured takeoff data** from AR scans
2. **Database-driven assemblies** (kitchen, bathroom combinations)
3. **Production rates** for precise labor calculations
4. **Localized cost data** with retail price overrides

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL 13+
- Firebase project with Admin SDK

### Environment Setup
```bash
cp .env.example .env
# Edit .env with your database and Firebase credentials
```

### Installation
```bash
npm install
```

### Database Setup
The database schema is managed by the database-engineer agent. Ensure the ContractorLens schema is deployed:

```sql
-- Applied from database/schemas/schema.sql
CREATE SCHEMA contractorlens;
-- Items, Assemblies, LocationCostModifiers, RetailPrices tables
```

### Start Development Server
```bash
npm run dev
```

### Production
```bash
npm start
```

## 📊 Assembly Engine Core

### Cost Calculation Hierarchy

1. **Retail Prices** (if fresh within 7 days)
   ```sql
   SELECT retail_price FROM RetailPrices 
   WHERE last_scraped > NOW() - INTERVAL '7 days'
   ```

2. **National Average × Location Modifier** (fallback)
   ```sql
   SELECT national_average_cost * location_modifier
   FROM Items JOIN LocationCostModifiers
   ```

### Production Rate Calculations

Labor hours are calculated using precise production rates:
```javascript
const laborHours = quantity * component.quantity_per_unit;
const laborCost = laborHours * userSettings.hourly_rate;
```

Example: Drywall installation
- Production rate: `0.016 hours/SF`
- For 1000 SF: `1000 × 0.016 = 16 labor hours`

## 🛠️ API Endpoints

### Base URL
- Development: `http://localhost:3000`
- Production: `https://api.contractorlens.com`

### Authentication
All endpoints require Firebase ID token:
```
Authorization: Bearer <firebase_id_token>
```

### Core Endpoints

> **NEW**: Enhanced AI workflow available! Use `/api/v1/analysis/enhanced-estimate` for the premium AR + Gemini analysis experience.

#### POST /api/v1/estimates
Create new estimate using Assembly Engine

**Request Body:**
```json
{
  "takeoffData": {
    "walls": [{"area": 1200, "type": "drywall"}],
    "floors": [{"area": 800, "type": "hardwood"}],
    "kitchens": [{"area": 200}]
  },
  "jobType": "kitchen",
  "finishLevel": "better",
  "zipCode": "10001",
  "notes": "Client prefers premium finishes"
}
```

**Response:**
```json
{
  "estimateId": "uuid",
  "status": "draft",
  "lineItems": [...],
  "subtotal": 45000.00,
  "markupAmount": 11250.00,
  "taxAmount": 3600.00,
  "grandTotal": 59850.00,
  "metadata": {
    "totalLaborHours": 120,
    "finishLevel": "better",
    "location": {...}
  }
}
```

#### GET /api/v1/estimates
List estimates with pagination and filtering

**Query Parameters:**
- `page` (default: 1)
- `limit` (default: 10)
- `status` (draft, approved, invoiced, archived)
- `projectId` (UUID)

#### GET /api/v1/estimates/:id
Retrieve specific estimate with full line items

#### PUT /api/v1/estimates/:id/status
Update estimate status

**Body:**
```json
{
  "status": "approved"
}
```

#### DELETE /api/v1/estimates/:id
Delete draft estimate

### 🤖 AI-Enhanced Analysis Endpoints

#### POST /api/v1/analysis/enhanced-estimate
**Premium Workflow**: Create AI-enhanced estimate using AR scan + Gemini analysis

**Request Body:**
```json
{
  "enhancedScanData": {
    "scan_id": "scan-uuid",
    "room_type": "kitchen",
    "takeoff_data": {
      "walls": [{"area": 320, "height": 9}],
      "floors": [{"area": 120}],
      "kitchens": [{"area": 120}]
    },
    "dimensions": {
      "length": 12,
      "width": 10,
      "height": 9,
      "total_area": 120
    },
    "frames": [
      {
        "timestamp": "2025-09-03T21:00:00Z",
        "imageData": "base64-encoded-image-data",
        "mimeType": "image/jpeg",
        "lighting_conditions": "good"
      }
    ]
  },
  "finishLevel": "better",
  "zipCode": "10001",
  "fallbackToBasic": true
}
```

**Response**: Enhanced estimate with AI analysis insights
```json
{
  "estimateId": "uuid",
  "analysisMethod": "enhanced",
  "lineItems": [...],
  "grandTotal": 65250.00,
  "ai_analysis": {
    "room_analysis": {
      "room_type": "kitchen",
      "overall_condition": "good",
      "complexity_level": "medium"
    },
    "surface_insights": {
      "flooring": {
        "current": "vinyl",
        "condition": "fair",
        "removal_required": true,
        "recommendations": {...}
      },
      "walls": {
        "material": "drywall",
        "condition": "good",
        "repairs_needed": 1
      }
    },
    "assembly_recommendations": {
      "suggested": ["kitchen_standard"],
      "rationale": "Existing conditions support better tier materials"
    }
  },
  "metadata": {
    "ai_enhanced": true,
    "analysis_confidence": 0.9,
    "frames_analyzed": 5
  }
}
```

#### POST /api/v1/analysis/room-analysis
Analyze room images without creating estimate (preview mode)

**Request Body:**
```json
{
  "scan_id": "scan-uuid",
  "room_type": "kitchen", 
  "dimensions": {...},
  "frames": [...]
}
```

**Response**: Gemini analysis results only
```json
{
  "scan_id": "scan-uuid",
  "analysis_completed": true,
  "room_analysis": {
    "surfaces": {...},
    "complexity_factors": {...},
    "assembly_recommendations": {...}
  }
}
```

#### GET /api/v1/analysis/health
Gemini integration service health check

#### GET /api/v1/analysis/capabilities  
Service capabilities and supported room types

### Utility Endpoints

#### GET /health
System health check with database connectivity

#### GET /api/v1
API documentation and available endpoints

## 🗂️ Project Structure

```
backend/
├── src/
│   ├── config/
│   │   ├── database.js          # PostgreSQL connection
│   │   └── firebase.js          # Firebase Admin SDK
│   ├── middleware/
│   │   └── auth.js              # Firebase authentication
│   ├── routes/
│   │   └── estimates.js         # Estimates CRUD endpoints
│   ├── services/
│   │   └── assemblyEngine.js    # Core calculation engine
│   └── server.js                # Express server setup
├── package.json
├── .env.example
└── README.md
```

## 🧮 Assembly Engine Details

### Input: Takeoff Data Structure
```javascript
{
  walls: [{area: 1200, height: 9, type: "drywall"}],
  floors: [{area: 800, type: "hardwood"}],
  ceilings: [{area: 800, type: "painted"}],
  kitchens: [{area: 200}],
  bathrooms: [{area: 60}]
}
```

### Assembly Matching Logic
- **Kitchen assemblies**: Match to `takeoffData.kitchens`
- **Bathroom assemblies**: Match to `takeoffData.bathrooms`
- **Wall assemblies**: Sum all wall areas
- **Flooring assemblies**: Sum all floor areas

### Cost Localization
```javascript
// 1. Check retail prices (fresh data priority)
const retailPrice = await getRetailPrice(itemId, locationId);

// 2. Fallback to national average with modifier
const localizedCost = nationalCost * locationModifier;
```

## 🔧 Configuration

### Environment Variables
```env
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/contractorlens
DB_HOST=localhost
DB_PORT=5432
DB_NAME=contractorlens

# Firebase
FIREBASE_PROJECT_ID=contractorlens
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----..."
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-@contractorlens.iam.gserviceaccount.com

# Server
PORT=3000
NODE_ENV=development

# Assembly Engine
DEFAULT_MARKUP_PERCENTAGE=25
DEFAULT_TAX_RATE=0.08
RETAIL_PRICE_FRESHNESS_DAYS=7
```

## 🚨 Error Handling

The API uses consistent error response format:
```json
{
  "error": "Human readable error message",
  "code": "MACHINE_READABLE_CODE",
  "details": {...} // Optional validation details
}
```

### Common Error Codes
- `VALIDATION_FAILED`: Invalid request data
- `CALCULATION_FAILED`: Assembly Engine error
- `NOT_FOUND`: Resource doesn't exist
- `UNAUTHORIZED`: Invalid/missing auth token

## 🔍 Development & Testing

### Start with logging
```bash
NODE_ENV=development npm run dev
```

### Health check
```bash
curl http://localhost:3000/health
```

### Test estimate calculation
```bash
curl -X POST http://localhost:3000/api/v1/estimates \
  -H "Authorization: Bearer <firebase_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "takeoffData": {"walls": [{"area": 1000}]},
    "jobType": "room",
    "finishLevel": "good",
    "zipCode": "10001"
  }'
```

## 🏭 Production Deployment

### Google Cloud Run
The backend is designed for Cloud Run deployment:

```dockerfile
# Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY src/ ./src/
EXPOSE 3000
CMD ["npm", "start"]
```

### Environment Setup
- PostgreSQL: Cloud SQL instance
- Firebase: Production project credentials
- Secrets: Google Secret Manager

## 📈 Integration Points

### Database Schema
Depends on database-engineer deliverables:
- `contractorlens.Items` - Materials and labor with production rates
- `contractorlens.Assemblies` - Pre-defined job combinations
- `contractorlens.LocationCostModifiers` - Geographic cost multipliers
- `contractorlens.RetailPrices` - Real-time localized pricing

### iOS App Integration
iOS app consumes estimates API for:
- Sending AR takeoff data → `POST /api/v1/estimates`
- Retrieving estimates → `GET /api/v1/estimates`
- Status updates → `PUT /api/v1/estimates/:id/status`

### ML Services Integration
Gemini digital surveyor enhances takeoff data but does NOT calculate costs.

## 🎯 Key Features

### Core Assembly Engine
- ✅ **Deterministic calculations** (not AI estimation)
- ✅ **Production rate precision** (DECIMAL 10,6)
- ✅ **Cost hierarchy** (retail override → national × modifier)
- ✅ **Firebase authentication** integration
- ✅ **Comprehensive error handling**
- ✅ **Cloud-ready architecture**
- ✅ **RESTful API design**

### 🤖 NEW: AI Enhancement Layer (INT002)
- ✅ **Gemini Vision integration** for material identification
- ✅ **Condition assessment** from room images
- ✅ **Complexity analysis** with automatic modifiers
- ✅ **Assembly recommendations** based on visual analysis
- ✅ **Fallback support** to basic estimates
- ✅ **Enhanced takeoff data** with AI insights
- ✅ **Quality tier optimization** based on existing conditions

### Integration Architecture
```
AR Scan → Gemini Analysis → Enhanced Takeoff → Assembly Engine → AI-Enhanced Estimate
     ↘                                      ↗
       Traditional Takeoff → Assembly Engine → Basic Estimate
```

## 🧪 Testing

### Unit Tests
Run integration tests to verify functionality:
```bash
cd backend
node tests/unit.test.js
```

**Latest Results**: ✅ All 4 tests passed
- Takeoff data enhancement logic
- Complexity modifier calculations  
- Job type determination
- Health check functionality

### Integration Workflow
1. **Basic estimates**: `/api/v1/estimates` (deterministic Assembly Engine)
2. **Enhanced estimates**: `/api/v1/analysis/enhanced-estimate` (AR + AI + Assembly Engine)
3. **Fallback handling**: Automatic degradation if Gemini unavailable

---

**Backend Engineer**: Assembly Engine + ML Integration operational and ready for production 🚀🤖
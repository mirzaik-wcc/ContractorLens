const db = require('../config/database');

class LaborCalculator {
  /**
   * Calculates the total labor hours for a given task, including adjustments.
   * @param {object} item - The database item object (which is a labor type).
   * @param {number} quantity - The quantity of work to be done (e.g., 120 SF).
   * @param {object} roomConditions - Conditions from the scan that might affect labor.
   * @returns {Promise<object>} - An object containing a detailed labor hour breakdown.
   */
  async calculateLaborHours(item, quantity, roomConditions) {
    // 1. Get base task information from the new LaborTasks table
    const laborTask = await this.getLaborTask(item.item_id);

    if (!laborTask) {
      // Fallback for labor items not yet in the new table
      return {
        base_hours: quantity * (item.quantity_per_unit || 0.1), // Legacy fallback
        total_hours: quantity * (item.quantity_per_unit || 0.1) * 1.1, // Default 10% complexity
        labor_details: { applied_default: true },
      };
    }

    // 2. Calculate base hours
    const baseHours = quantity * laborTask.base_production_rate;

    // 3. Apply difficulty multipliers
    const difficultyMultiplier = this.calculateDifficultyMultiplier(roomConditions, laborTask);

    // 4. Add setup and cleanup time
    const setupCleanupHours = laborTask.setup_time_hours + laborTask.cleanup_time_hours;

    const totalHours = (baseHours * difficultyMultiplier) + setupCleanupHours;

    // 5. Get the cost for the calculated hours
    const hourlyRate = await this.getLaborRate(laborTask.skill_level, roomConditions.zipCode);

    return {
      base_hours: baseHours,
      total_hours: totalHours,
      labor_details: {
        difficulty_adjustment_factor: difficultyMultiplier,
        setup_cleanup_hours: setupCleanupHours,
        skill_level: laborTask.skill_level,
      },
      total_labor_cost: totalHours * hourlyRate,
    };
  }

  /**
   * Retrieves labor task details for a given item from the database.
   * @param {string} itemId - The UUID of the item.
   * @returns {Promise<object|null>}
   */
  async getLaborTask(itemId) {
    const query = 'SELECT * FROM LaborTasks WHERE item_id = $1';
    const { rows } = await db.query(query, [itemId]);
    return rows[0] || null;
  }

  /**
   * Calculates a difficulty multiplier based on room conditions.
   * @param {object} conditions - The room conditions from the scan.
   * @param {object} laborTask - The labor task details.
   * @returns {number} - A multiplier (e.g., 1.0 for standard, 1.25 for difficult).
   */
  calculateDifficultyMultiplier(conditions, laborTask) {
    let multiplier = laborTask.difficulty_multiplier || 1.0;

    // Example of future logic:
    // if (conditions.access === 'difficult') multiplier *= 1.15;
    // if (conditions.requires_scaffolding) multiplier *= 1.2;

    return multiplier;
  }

  /**
   * Retrieves the hourly rate for a given skill level and location.
   * @param {string} skillLevel - e.g., 'apprentice', 'journeyman', 'master'.
   * @param {string} zipCode - The ZIP code of the job.
   * @returns {Promise<number>} - The calculated hourly rate.
   */
  async getLaborRate(skillLevel, zipCode) {
    // TODO: Implement more sophisticated rate lookup, potentially joining
    // with the Trades and LocationCostModifiers tables.
    const baseRate = 50; // Default base rate
    let skillMultiplier = 1.0;

    if (skillLevel === 'journeyman') skillMultiplier = 1.5;
    if (skillLevel === 'master') skillMultiplier = 2.0;

    return baseRate * skillMultiplier;
  }
}

module.exports = new LaborCalculator();

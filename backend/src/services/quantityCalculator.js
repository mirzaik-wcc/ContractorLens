const db = require('../config/database');

class QuantityCalculator {
  /**
   * Calculates the required quantity of a material, including waste factors.
   * @param {object} item - The database item object.
   * @param {number} measurement - The base measurement from the scan (e.g., 120 SF).
   * @param {object} roomConditions - Conditions from the scan that might affect waste.
   * @returns {Promise<object>} - An object containing detailed quantity breakdown.
   */
  async calculateMaterialQuantity(item, measurement, roomConditions) {
    // 1. Get waste factors for this material type from the new table
    const wasteFactor = await this.getWasteFactors(item.item_id);

    if (!wasteFactor) {
      // If no specific waste factors are defined, return a simple calculation
      return {
        base_quantity: measurement,
        total_quantity: measurement * 1.10, // Default 10% waste
        waste_details: { applied_default: true, percentage: 10 },
      };
    }

    // 2. Apply waste calculations
    const baseQuantity = measurement;
    const cutWaste = this.calculateCutWaste(item, measurement, wasteFactor);
    const breakageWaste = baseQuantity * (wasteFactor.breakage_percentage / 100);
    const patternMatchWaste = baseQuantity * (wasteFactor.pattern_match_percentage / 100);

    // 3. Room condition adjustments (future enhancement)
    const conditionMultiplier = this.getConditionMultiplier(roomConditions);

    const totalQuantity = Math.ceil(
      (baseQuantity + cutWaste + breakageWaste + patternMatchWaste) * conditionMultiplier
    );

    return {
      base_quantity: baseQuantity,
      total_quantity: totalQuantity,
      waste_details: {
        cut_waste: cutWaste,
        breakage_waste: breakageWaste,
        pattern_match_waste: patternMatchWaste,
        total_waste_percentage: ((totalQuantity - baseQuantity) / baseQuantity) * 100,
      },
      condition_adjustment: (conditionMultiplier - 1) * baseQuantity,
    };
  }

  /**
   * Retrieves waste factors for a given item from the database.
   * @param {string} itemId - The UUID of the item.
   * @returns {Promise<object|null>}
   */
  async getWasteFactors(itemId) {
    const query = 'SELECT * FROM WasteFactors WHERE item_id = $1';
    const { rows } = await db.query(query, [itemId]);
    return rows[0] || null;
  }

  /**
   * Placeholder for complex cut waste calculation.
   * For now, applies a simple percentage.
   */
  calculateCutWaste(item, measurement, wasteFactor) {
    // TODO: Implement more complex logic for sheet goods vs. linear materials
    return measurement * (wasteFactor.cut_waste_percentage / 100);
  }

  /**
   * Placeholder for condition-based multipliers.
   * For now, returns 1.0 (no adjustment).
   */
  getConditionMultiplier(roomConditions) {
    // TODO: Implement logic based on room complexity, access, etc.
    return 1.0;
  }
}

module.exports = new QuantityCalculator();

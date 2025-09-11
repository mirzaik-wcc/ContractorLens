const db = require('../config/database');

class ProductCatalog {
  /**
   * Enriches a line item with detailed specifications from the database.
   * @param {object} item - The database item object.
   * @returns {Promise<object>} - The item enriched with manufacturer and spec data.
   */
  async enrichItemWithSpecs(item) {
    // 1. Get the detailed specifications from the new MaterialSpecifications table
    const specs = await this.getMaterialSpecs(item.item_id);

    // 2. Get manufacturer and model number from the newly altered Items table
    const enrichedItem = {
      ...item,
      manufacturer: item.manufacturer, // From the altered Items table
      model_number: item.model_number,   // From the altered Items table
      specifications: specs, // From the new MaterialSpecifications table
    };

    // 3. In the future, this is where live API calls to suppliers would go.
    // const supplierData = await this.fetchSupplierPricing(item.model_number);
    // enrichedItem.real_time_price = supplierData.price;

    return enrichedItem;
  }

  /**
   * Retrieves material specifications for a given item from the database.
   * @param {string} itemId - The UUID of the item.
   * @returns {Promise<object|null>}
   */
  async getMaterialSpecs(itemId) {
    const query = 'SELECT * FROM MaterialSpecifications WHERE item_id = $1';
    const { rows } = await db.query(query, [itemId]);
    return rows[0] || null;
  }

  /**
   * Placeholder for future live supplier API integration.
   */
  async fetchSupplierPricing(modelNumber) {
    // This is where you would implement fetch calls to Home Depot, Lowe's, etc.
    console.log(`Future enhancement: Fetching live price for ${modelNumber}`);
    return {
      price: null, // Placeholder
      availability: 'unknown',
    };
  }
}

module.exports = new ProductCatalog();

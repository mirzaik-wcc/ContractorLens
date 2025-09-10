# Project Roadmap: Estimate Granularity Overhaul

## 1. Introduction & Business Need

This document outlines the development plan to evolve the ContractorLens estimate generation system from its current state to a professional-grade, highly granular output.

**Business Need:** The current system provides a solid proof-of-concept but lacks the detailed, defensible data required by professional contractors. To be a market-competitive tool, estimates must include line-item specifics on materials (manufacturer, model), labor (task-specific hours, difficulty), and waste calculations. This overhaul is critical for user adoption and commercial viability.

**Current State (Level 2):** The system uses a deterministic "Assembly Engine" that correctly maps scanned room elements to pre-defined assemblies. It successfully generates a line-item estimate grouped by a simple category.

**Target State (Level 5):** The system will produce a detailed, multi-layered estimate organized by official CSI MasterFormat divisions. It will feature precise calculations for material waste, task-specific labor hours based on room conditions, and detailed material specifications, providing a transparent, auditable, and professional final report.

## 2. Development Plan

The project is divided into five distinct phases, building from the database foundation up to the user interface.

**Estimated Total Effort:** 18 - 28 developer-days.

---

### **Phase 1: Database Schema Foundation**

**Goal:** Establish the necessary database structure to store granular material, labor, trade, and waste data. This is the bedrock for all subsequent logic.
**Effort Estimate:** 2-3 days

*   **Step 1.1: Create a New Database Migration Script.**
    *   **Action:** Create a new file: `database/migrations/V2__add_professional_estimate_tables.sql`. Using a migration script ensures changes are version-controlled and repeatable.

*   **Step 1.2: Implement New Granularity Tables.**
    *   **Action:** Add the `CREATE TABLE` statements for `Trades`, `MaterialSpecifications`, `LaborTasks`, `WasteFactors`, and `WorkSequences`.

*   **Step 1.3: Alter the Existing `Items` Table.**
    *   **Action:** Add `ALTER TABLE` statements to the `Items` table to link it to the new structure (e.g., `trade_id`, `manufacturer`, `model_number`).

---

### **Phase 2: Implement Specialized Calculation Services**

**Goal:** Create new, single-responsibility services to handle the complex calculations for quantity, labor, and material enrichment.
**Effort Estimate:** 8-12 days

*   **Step 2.1: Create the `QuantityCalculator` Service.**
    *   **Action:** Create `backend/src/services/quantityCalculator.js`.
    *   **Implementation:** Implement logic to query the `WasteFactors` table and calculate material quantities including base, cut, and breakage waste.

*   **Step 2.2: Create the `LaborCalculator` Service.**
    *   **Action:** Create `backend/src/services/laborCalculator.js`.
    *   **Implementation:** Implement logic to query the `LaborTasks` table and calculate labor hours based on production rates, room conditions, and crew size.

*   **Step 2.3: Create the `ProductCatalog` Service.**
    *   **Action:** Create `backend/src/services/productCatalog.js`.
    *   **Implementation:** Implement logic to query the `MaterialSpecifications` table. (Note: Live supplier API integration will be a future iteration).

---

### **Phase 3: Refactor the Assembly Engine**

**Goal:** Upgrade the existing `assemblyEngine.js` to act as an orchestrator, delegating its calculation tasks to the new, specialized services.
**Effort Estimate:** 3-5 days

*   **Step 3.1: Modify `generateDetailedEstimate` Method.**
    *   **Action:** Refactor the main calculation loop in `backend/src/services/assemblyEngine.js`.
    *   **New Logic:** The engine will now call the new `QuantityCalculator`, `LaborCalculator`, and `ProductCatalog` services for each item to generate a rich, detailed line-item object.

*   **Step 3.2: Implement CSI-Based Organization.**
    *   **Action:** Add logic to group the final line items based on the new `Trades` table, organizing the estimate by CSI divisions.

---

### **Phase 4: Data Seeding & API Finalization**

**Goal:** Populate the new database tables with sample data and update the API response to expose the new, granular estimate structure.
**Effort Estimate:** 2-3 days

*   **Step 4.1: Create New Seed Scripts.**
    *   **Action:** Create new seed files in `database/seeds/` for `trades.sql`, `labor_tasks.sql`, and `material_specifications.sql` with sample data for testing.

*   **Step 4.2: Update the API Response Format.**
    *   **Action:** Modify the final JSON object returned by the `/generate` endpoint to reflect the new, deeply nested, CSI-organized structure.

---

### **Phase 5: iOS Frontend Adaptation**

**Goal:** Update the iOS application to correctly parse and display the new, professional-grade estimate format.
**Effort Estimate:** 3-5 days

*   **Step 5.1: Update Swift `Codable` Models.**
    *   **Action:** Modify the structs in `ios-app/ContractorLens/Models/Estimate.swift` to match the new, detailed API response.

*   **Step 5.2: Enhance the `EstimateResultsView`.**
    *   **Action:** Modify the SwiftUI code in `ios-app/ContractorLens/Views/EstimateResultsView.swift` to render the new nested structure, likely making line items expandable to show the full granularity.

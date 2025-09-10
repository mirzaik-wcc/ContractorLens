# GEMINI.md

## Project Overview

This repository contains the source code for **ContractorLens**, a construction cost estimation tool. The project is composed of three main components:

1.  **Backend:** A Node.js/Express application that provides a RESTful API for managing estimates. It features a deterministic "Assembly Engine" for cost calculations based on structured data.
2.  **iOS App:** A SwiftUI-based mobile application that allows users to scan rooms using AR (Augmented Reality) to create 3D models and capture takeoff data.
3.  **Gemini ML Service:** A Node.js service that acts as a "digital surveyor." It uses Google's Gemini model to analyze images from the AR scans, identify materials, assess their condition, and provide recommendations. This service does **not** perform cost estimation.

The overall architecture is designed to separate concerns: the iOS app handles data capture, the Gemini service analyzes the data, and the backend performs the final cost calculations.

## Building and Running

The entire ContractorLens application can be run using Docker Compose.

### Prerequisites

*   Docker and Docker Compose
*   Node.js and npm (for running services individually)
*   An environment file (`.env`) with the necessary credentials for Firebase and Gemini. An example is provided in `.env.example`.

### Running with Docker Compose

To run the entire application, use the following command from the project root:

```bash
docker-compose up -d
```

This will start the following services:

*   `postgres`: The PostgreSQL database.
*   `backend`: The main backend application.
*   `gemini-service`: The Gemini ML service.
*   `nginx`: An Nginx reverse proxy.

### Running Services Individually

#### Backend

To run the backend service individually:

```bash
cd backend
npm install
npm run dev
```

The backend will be available at `http://localhost:3000`.

#### Gemini ML Service

To run the Gemini ML service individually:

```bash
cd ml-services/gemini-service
npm install
npm start
```

The Gemini service will be available at `http://localhost:3001`.

### Testing

#### Backend

To run the backend tests:

```bash
cd backend
node tests/unit.test.js
```

#### Gemini ML Service

To run the Gemini ML service tests:

```bash
cd ml-services/gemini-service
npm test
```

## Development Conventions

*   **Backend:** The backend follows a standard Node.js/Express project structure. It uses Firebase for authentication and a PostgreSQL database for data storage. The core business logic is encapsulated in the "Assembly Engine."
*   **iOS App:** The iOS app is built with SwiftUI and uses the `ARKit` and `RoomPlan` frameworks for its scanning capabilities. It communicates with the backend API to send and receive data.
*   **Gemini ML Service:** The Gemini service is a stateless Node.js application that receives scan data, analyzes it using the Gemini API, and returns a structured JSON response. It has a clear separation of concerns and does not handle any cost calculations.
*   **Docker:** The entire application is containerized using Docker, and the `docker-compose.yml` file orchestrates the different services.

# MAPSI

## Description

MAPSI is an AI-powered travel planning application that helps users generate realistic and structured travel itineraries based on their preferences, destination, budget, and schedule. The app combines user input with external travel data to create personalized trip plans, supported by a backend system built with FastAPI, Firebase, PostgreSQL, Redis, OpenAI, Google Places, Google Maps, and Amadeus APIs.

This project was originally built as a group school project. This repository is a cleaned public portfolio version, with private course materials and sensitive configuration files removed.

## Motivation

The motivation behind MAPSI came from how difficult and time-consuming travel planning can be. Planning a trip often requires users to search across multiple platforms for destinations, activities, flights, maps, and schedules. Our goal was to create an application that could simplify this process by using AI and travel APIs to generate organized, realistic itineraries in one place.

For me, this project was also an opportunity to gain practical experience in backend development, API integration, deployment, authentication, database design, caching, and AI-powered application features.

## Table of Contents

* [Description](#description)
* [Motivation](#motivation)
* [Outline](#outline)
* [Usage](#usage)
* [Features](#features)
* [Results and Discussion](#results-and-discussion)
* [Learning Experience](#learning-experience)
* [Backend Authentication and User System](#backend-authentication-and-user-system)
* [AI Itinerary Generation](#ai-itinerary-generation)
* [Database and API Design](#database-and-api-design)
* [External API Integration](#external-api-integration)
* [Deployment and Reliability](#deployment-and-reliability)
* [Challenges Faced](#challenges-faced)
* [Lessons Learned](#lessons-learned)
* [Conclusion](#conclusion)
* [Credits](#credits)
* [Badges](#badges)

## Outline

* Backend developed using Python and FastAPI.
* Authentication and user system implemented with Firebase.
* Database built using PostgreSQL with SQLAlchemy.
* AI itinerary generation powered by OpenAI.
* Travel and location data integrated through Google Places, Google Maps, and Amadeus APIs.
* Redis caching used to improve performance and reduce repeated external API calls.
* REST APIs developed for trip management, itinerary editing, and collaborative features.
* Backend services deployed and configured for use outside the local development environment.
* Frontend developed as an iOS application using Swift and SwiftUI.
* Developed through a team-based GitHub workflow.

## Usage

This repository is intended as a public portfolio version of the MAPSI project.

To explore the project locally:

1. Clone the repository.

```bash
git clone https://github.com/rachellyoum/mapsi-public.git
```

2. Open the frontend iOS project in Xcode.

```text
frontend/ios/TravelPlanner/TravelPlanner.xcodeproj
```

3. Check the backend folder for server-side code and setup.

```text
backend/
```

4. Run the app using an iOS simulator and connect it to the backend environment.

> Note: Some API keys, environment variables, and private deployment settings have been removed from this public version for security reasons.

<!-- ## Demo -->

<!-- Add a screenshot or demo video here if available. -->

<!-- Example:
[![MAPSI demo screenshot](./assets/demo-screenshot.png)](./assets/demo.mp4)
-->

## Features

### Account and Authentication

* Firebase-based authentication
* Secure user access flow
* User data synchronization between authentication and backend services
* Backend validation for protected user-related operations

### AI Itinerary Generation

* AI-generated travel itineraries using OpenAI
* Google Places data used to make generated plans more realistic
* Structured itinerary output for easier frontend display
* Travel plans based on user preferences such as destination, budget, schedule, and interests

### Trip Management

* REST API support for creating and managing trips
* Backend support for itinerary editing
* Database-backed trip storage
* API structure designed for future collaborative planning features

### External API Integrations

* Google Places API for destination and place data
* Google Maps integration for location-based travel features
* Amadeus API integration for travel-related data
* OpenAI API integration for AI-powered itinerary generation

### Performance and Reliability

* Redis caching to reduce repeated API calls
* Improved response performance for external API data
* Structured error handling across backend services
* Validation for safer API requests and more predictable backend behavior

### iOS Frontend

* Swift and SwiftUI-based mobile app
* Travel questionnaire flow
* Clean mobile-first interface
* Custom visual assets, launch screen, and app branding

## Results and Discussion

MAPSI gave our team the opportunity to build a travel planning application that combines mobile development, backend engineering, AI integration, and deployment. My main focus was on the backend and deployment side, including authentication, REST API development, database integration, external API connections, caching, and reliability improvements.

The project demonstrated how a mobile app can become more powerful when supported by a well-structured backend. The frontend provides the user experience, while the backend handles authentication, trip data, itinerary generation, external API calls, caching, and deployment.

## Learning Experience

### Backend Authentication and User System

Working on MAPSI helped me understand how authentication fits into a full application. I designed and implemented backend authentication and user systems using Firebase and FastAPI, allowing the app to securely manage user access and synchronize user-related data with backend services.

### AI Itinerary Generation

One of the most valuable parts of the project was building the AI-driven itinerary generation system. I worked with OpenAI and Google Places data to generate structured travel plans that were more realistic and useful for users. This helped me understand how AI features can be grounded with external data instead of relying only on general text generation.

### Database and API Design

I developed scalable REST APIs using FastAPI, PostgreSQL, and SQLAlchemy to support trip management, itinerary editing, and collaborative planning features. This gave me more practice designing backend routes, organizing data models, and connecting application features to persistent storage.

### External API Integration

MAPSI required integrating multiple external APIs, including Google Maps, Google Places, and Amadeus. This helped me learn how to work with third-party API responses, handle API limitations, structure returned data, and manage service reliability.

### Deployment and Reliability

Deployment was another major learning experience. I worked on preparing the backend to run outside of a local development environment and improved reliability through structured error handling and validation across backend services. I also implemented Redis caching to improve performance and reduce latency from repeated external API calls.

## Challenges Faced

### Combining AI with Real Travel Data

A major challenge was making AI-generated itineraries feel realistic and structured. Instead of only generating generic travel suggestions, the system needed to combine AI output with real place and travel data from external APIs.

### Managing Multiple External APIs

Working with OpenAI, Google Places, Google Maps, and Amadeus introduced challenges around request formatting, response handling, latency, and error cases. Each API had different data structures and requirements, so the backend needed careful organization.

### Backend Deployment

Moving the backend from local development to a deployed environment required extra attention to configuration, environment variables, dependencies, and debugging. This helped me better understand the difference between code that works locally and code that is ready to run in a real environment.

### Preparing a Public Portfolio Version

Since this was originally a group school project, another challenge was preparing a clean public version. Private files, course materials, API keys, deployment secrets, and sensitive configuration files needed to be removed before publishing.

## Lessons Learned

This project taught me that backend development involves much more than creating endpoints. A strong backend also needs authentication, database structure, external API handling, caching, validation, error handling, and deployment planning.

I also learned that AI features are more useful when they are connected to real data. By combining OpenAI with Google Places and travel-related APIs, MAPSI was able to produce more practical itinerary results than a basic prompt-only system.

Finally, this project helped me understand how to present a group project professionally by clearly explaining my contributions and preparing a privacy-safe public repository.

## Conclusion

MAPSI was a meaningful project because it allowed me to work on backend development, AI integration, REST API design, database management, caching, deployment, and mobile app support within a team-based project. It strengthened my interest in backend and full-stack development, especially projects that combine real-world APIs with AI-powered features.

## Credits

This was a group project.

My main contributions included:

* Designed and implemented backend authentication and user systems using Firebase and FastAPI
* Built an AI-driven itinerary generation system using OpenAI and Google Places data
* Developed REST APIs with PostgreSQL and SQLAlchemy for trip management, itinerary editing, and collaborative features
* Integrated external APIs including Google Maps and Amadeus
* Implemented Redis caching to improve performance and reduce latency
* Improved system reliability with structured error handling and validation
* Worked on backend deployment and configuration
* Helped prepare this cleaned public version for portfolio use

## Badges

Python
FastAPI
Firebase
PostgreSQL
SQLAlchemy
Redis
OpenAI API
Google Places API
Google Maps API
Amadeus API
REST APIs
Backend Development
Deployment
Swift
SwiftUI
Git
GitHub

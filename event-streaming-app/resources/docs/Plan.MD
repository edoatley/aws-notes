# Project Plan: UK TV Guide Enhancements

## Overview
This document outlines the plan to enhance the UK TV Guide application, focusing on improving the web UI, ensuring data flow from the backend to the frontend, and establishing a clear administrative interface for triggering backend processes. Additionally, it addresses the need for refined application requirements and a comprehensive user guide.

## Goals
1.  **Establish a clear plan document:** Break down the current request into manageable, trackable tasks.
2.  **Refine application requirements and user guide:** Clearly define the application's functionality and create user-centric documentation.
3.  **Populate backend data:** Ensure the DynamoDB table contains necessary reference data, user preferences, and title recommendations.
4.  **Verify web API functionality:** Confirm the web API correctly retrieves and serves data from DynamoDB to the frontend.
5.  **Develop an Admin Screen:** Create a web UI interface for easy triggering of backend data ingestion processes.
6.  **Enhance Web UI Aesthetics:** Improve the visual appeal and user experience of the existing web application.

## Detailed Plan

### Phase 1: Planning and Documentation
- [ ] Create this `Plan.MD` document.
- [ ] Review and refine existing requirements in `Event-Streaming.MD`.
- [ ] Outline the structure and content for a new User Guide.

### Phase 2: Backend Data Population and Verification
- [x] Trigger `event-streaming-app/src/periodic_reference_data` to populate sources and genres in DynamoDB.
- [x] Add sample user preference data via `event-streaming-app/src/user_preferences`.
- [x] Trigger `event-streaming-app/src/userprefs_title_ingestion/` to ingest titles and recommendations based on preferences.
- [x] Verify that DynamoDB contains the correct data
- [x] Verify that the web API (`event-streaming-app/src/web_api/web_api.py`) successfully returns data (sources, genres, preferences, titles, recommendations) from DynamoDB.
- [x] Verify that the web front end (`event-streaming-app/src/web/index.html.py`) displays the data correctly.
- [x] Create API Key for web API
- [ ] Create tests to validate the web API functionality.



### Phase 3: Admin Screen Design and Implementation (Deferred)
- [ ] **Design:** Plan the layout and functionality of the admin screen in Architect mode.
- [ ] **Implement:** Develop the admin screen UI and backend integration.

### Phase 4: Web UI Enhancements
- [ ] Review the current `event-streaming-app/src/web/index.html` and `event-streaming-app/src/web/app.js` for styling and layout improvements.
- [ ] Apply CSS and HTML modifications to enhance the visual appeal of the application, including the display of titles and recommendations.

### Phase 5: Testing improvements
- [ ] **Robust automated tests:** Enhance the bespoke testing approach with a test pack that validates the deployed application.

## Tracking Progress
This document will be updated regularly to reflect the status of each task.
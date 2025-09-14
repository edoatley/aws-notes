// Admin UI JavaScript

document.addEventListener('DOMContentLoaded', () => {
    // --- Configuration ---
    // Fetch API endpoint from config.js
    const adminApiBaseUrl = typeof window.appConfig !== 'undefined' && window.appConfig.AdminApiEndpoint ? window.appConfig.AdminApiEndpoint : '/api/admin'; // Fallback if not configured

    // --- DOM Elements ---
    const adminScreen = document.getElementById('admin-screen'); // Assuming a main container for admin UI
    const loginScreen = document.getElementById('login-screen'); // Assuming a login screen element

    const refreshReferenceDataButton = document.getElementById('refresh-reference-data');
    const referenceDataStatusDiv = document.getElementById('reference-data-status');
    const referenceDataLogsDiv = document.getElementById('reference-data-logs');

    const refreshTitleDataButton = document.getElementById('refresh-title-data');
    const titleDataStatusDiv = document.getElementById('title-data-status');
    const titleDataLogsDiv = document.getElementById('title-data-logs');

    const triggerEnrichmentButton = document.getElementById('trigger-enrichment');
    const enrichmentStatusDiv = document.getElementById('enrichment-status');
    const enrichmentLogsDiv = document.getElementById('enrichment-logs');
    const unenrichedTitlesCountDiv = document.getElementById('unenriched-titles-count');

    const generateDynamoDbSummaryButton = document.getElementById('generate-dynamodb-summary');
    const dynamoDbSummaryOutputDiv = document.getElementById('dynamodb-summary-output');

    const userStatusDiv = document.getElementById('user-status');
    const logoutButton = document.getElementById('logout-button');

    // --- Helper Functions ---
    const updateStatus = (element, message, type = 'info') => {
        element.textContent = message;
        element.className = `status-display ${type}`; // e.g., 'info', 'success', 'error'
    };

    const displayLogs = (element, logs) => {
        // Make logs collapsible if the element has a 'collapsible' class
        if (element && element.classList.contains('collapsible')) {
            element.innerHTML = `<button class="toggle-logs">Show Logs</button><pre style="display:none;">${logs}</pre>`;
            const toggleButton = element.querySelector('.toggle-logs');
            const logPre = element.querySelector('pre');
            toggleButton.addEventListener('click', () => {
                const isHidden = logPre.style.display === 'none' || logPre.style.display === '';
                logPre.style.display = isHidden ? 'block' : 'none';
                toggleButton.textContent = isHidden ? 'Hide Logs' : 'Show Logs';
            });
        } else {
            element.innerHTML = `<pre>${logs}</pre>`; // Basic log display if not collapsible
        }
    };

    const handleApiResponse = async (response, statusDiv, logsDiv = null, countDiv = null) => {
        try {
            const data = await response.json();
            if (response.ok) {
                if (statusDiv) {
                    updateStatus(statusDiv, data.message || 'Operation successful.', 'success');
                }
                if (data.job_id) {
                    // Display job ID and potentially logs if logsDiv is provided
                    if (logsDiv) {
                        logsDiv.innerHTML = `<p>Operation initiated. Job ID: ${data.job_id}</p>`;
                        // Optionally, add a button here to fetch logs for this job_id
                    }
                } else if (data.tables && dynamoDbSummaryOutputDiv) {
                    // For DynamoDB summary
                    let summaryHtml = '<ul>';
                    data.tables.forEach(table => {
                        summaryHtml += `<li><strong>${table.name}</strong>: Items: ${table.item_count}, Size: ${table.size_bytes}</li>`;
                    });
                    summaryHtml += '</ul>';
                    dynamoDbSummaryOutputDiv.innerHTML = summaryHtml;
                }
            } else {
                const errorMessage = data.message || `HTTP error! status: ${response.status}`;
                if (statusDiv) updateStatus(statusDiv, errorMessage, 'error');
                if (logsDiv) displayLogs(logsDiv, errorMessage); // Display error in logs section
            }
        } catch (error) {
            console.error("Error processing API response:", error);
            if (statusDiv) updateStatus(statusDiv, 'Error processing response.', 'error');
            if (logsDiv) displayLogs(logsDiv, `Error processing response: ${error.message}`);
        }
    };

    // --- Authentication ---
    const getAuthToken = () => localStorage.getItem('authToken');

    const isAuthenticated = () => {
        const token = getAuthToken();
        // Basic check: token exists. More robust check might involve token expiration.
        return !!token;
    };

    const showAdminScreen = () => {
        if (adminScreen && loginScreen) {
            adminScreen.style.display = 'block';
            loginScreen.style.display = 'none';
            userStatusDiv.textContent = 'Logged in as Admin'; // Placeholder
            logoutButton.style.display = 'block';
        }
    };

    const showLoginScreen = () => {
        if (adminScreen && loginScreen) {
            adminScreen.style.display = 'none';
            loginScreen.style.display = 'block';
            userStatusDiv.textContent = 'Not logged in';
            logoutButton.style.display = 'none';
        }
    };

    const handleLogout = () => {
        localStorage.removeItem('authToken'); // Clear token
        showLoginScreen();
        alert('Logged out successfully!');
    };

    // --- Event Listeners ---

    // Reference Data Refresh
    refreshReferenceDataButton.addEventListener('click', async () => {
        updateStatus(referenceDataStatusDiv, 'Refreshing...', 'info');
        if (referenceDataLogsDiv) referenceDataLogsDiv.innerHTML = ''; // Clear previous logs
        try {
            const response = await fetch(`${adminApiBaseUrl}/data/reference/refresh`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${getAuthToken()}` // Add Auth header
                }
            });
            handleApiResponse(response, referenceDataStatusDiv, referenceDataLogsDiv);
        } catch (error) {
            console.error('Error triggering reference data refresh:', error);
            updateStatus(referenceDataStatusDiv, 'Failed to connect to API.', 'error');
        }
    });

    // Title Data Refresh
    refreshTitleDataButton.addEventListener('click', async () => {
        updateStatus(titleDataStatusDiv, 'Refreshing...', 'info');
        if (titleDataLogsDiv) titleDataLogsDiv.innerHTML = '';
        try {
            const response = await fetch(`${adminApiBaseUrl}/data/titles/refresh`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${getAuthToken()}` // Add Auth header
                }
            });
            handleApiResponse(response, titleDataStatusDiv, titleDataLogsDiv);
        } catch (error) {
            console.error('Error triggering title data refresh:', error);
            updateStatus(titleDataStatusDiv, 'Failed to connect to API.', 'error');
        }
    });

    // Title Enrichment
    triggerEnrichmentButton.addEventListener('click', async () => {
        updateStatus(enrichmentStatusDiv, 'Enriching...', 'info');
        if (enrichmentLogsDiv) enrichmentLogsDiv.innerHTML = '';
        try {
            const response = await fetch(`${adminApiBaseUrl}/data/titles/enrich`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${getAuthToken()}` // Add Auth header
                }
            });
            handleApiResponse(response, enrichmentStatusDiv, enrichmentLogsDiv);
        } catch (error) {
            console.error('Error triggering title enrichment:', error);
            updateStatus(enrichmentStatusDiv, 'Failed to connect to API.', 'error');
        }
    });

    // DynamoDB Summary
    generateDynamoDbSummaryButton.addEventListener('click', async () => {
        updateStatus(dynamoDbSummaryOutputDiv, 'Generating summary...', 'info');
        try {
            const response = await fetch(`${adminApiBaseUrl}/system/dynamodb/summary`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${getAuthToken()}` // Add Auth header
                }
            });
            handleApiResponse(response, dynamoDbSummaryOutputDiv);
        } catch (error) {
            console.error('Error generating DynamoDB summary:', error);
            updateStatus(dynamoDbSummaryOutputDiv, 'Failed to connect to API.', 'error');
        }
    });

    // --- Initial Load and Authentication Check ---
    if (isAuthenticated()) {
        showAdminScreen();
    } else {
        showLoginScreen();
    }

    logoutButton.addEventListener('click', handleLogout);
});

// Global variables
let currentUser = null;
let userPool = null;
let userSession = null;
let sources = [];
let genres = [];

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
    setupEventListeners();
});

function initializeApp() {
    // Check if user is already authenticated
    checkAuthStatus();
    
    // Load available sources and genres
    loadSources();
    loadGenres();
}

function setupEventListeners() {
    document.getElementById('loginBtn').addEventListener('click', showLogin);
    document.getElementById('logoutBtn').addEventListener('click', logout);
    document.getElementById('updatePreferencesBtn').addEventListener('click', updatePreferences);
    
    // Tab change events
    document.getElementById('titles-tab').addEventListener('click', () => loadTitles());
    document.getElementById('recommendations-tab').addEventListener('click', () => loadRecommendations());
}

function showLogin() {
    document.getElementById('authSection').style.display = 'block';
    document.getElementById('mainContent').style.display = 'none';
}

function checkAuthStatus() {
    // Check if user is already authenticated
    const session = getCurrentSession();
    if (session && session.isValid()) {
        userSession = session;
        currentUser = session.username;
        onUserAuthenticated();
    } else {
        showLogin();
    }
}

function onUserAuthenticated() {
    document.getElementById('authSection').style.display = 'none';
    document.getElementById('mainContent').style.display = 'block';
    document.getElementById('loginBtn').style.display = 'none';
    document.getElementById('logoutBtn').style.display = 'block';
    
    // Load user preferences
    loadUserPreferences();
    
    // Load initial content
    loadTitles();
}

function logout() {
    if (userSession) {
        userSession.signOut();
    }
    currentUser = null;
    userSession = null;
    
    document.getElementById('mainContent').style.display = 'none';
    document.getElementById('loginBtn').style.display = 'block';
    document.getElementById('logoutBtn').style.display = 'none';
    showLogin();
}

// Cognito authentication functions
function getCurrentSession() {
    if (!userPool) {
        userPool = new AmazonCognitoIdentity.CognitoUserPool({
            UserPoolId: config.userPoolId,
            ClientId: config.userPoolClientId
        });
    }
    
    const cognitoUser = userPool.getCurrentUser();
    if (cognitoUser) {
        return new Promise((resolve, reject) => {
            cognitoUser.getSession((err, session) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(session);
                }
            });
        });
    }
    return null;
}

// API functions
async function loadSources() {
    try {
        const response = await fetch(`${config.preferencesApiEndpoint}/sources`);
        if (response.ok) {
            sources = await response.json();
            renderSourcesList();
        }
    } catch (error) {
        console.error('Error loading sources:', error);
    }
}

async function loadGenres() {
    try {
        const response = await fetch(`${config.preferencesApiEndpoint}/genres`);
        if (response.ok) {
            genres = await response.json();
            renderGenresList();
        }
    } catch (error) {
        console.error('Error loading genres:', error);
    }
}

async function loadUserPreferences() {
    try {
        const token = userSession.getIdToken().getJwtToken();
        const response = await fetch(`${config.preferencesApiEndpoint}/preferences`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (response.ok) {
            const preferences = await response.json();
            updatePreferencesUI(preferences);
        }
    } catch (error) {
        console.error('Error loading user preferences:', error);
    }
}

async function updatePreferences() {
    const selectedSources = Array.from(document.querySelectorAll('input[name="source"]:checked')).map(cb => cb.value);
    const selectedGenres = Array.from(document.querySelectorAll('input[name="genre"]:checked')).map(cb => cb.value);
    
    try {
        const token = userSession.getIdToken().getJwtToken();
        const response = await fetch(`${config.preferencesApiEndpoint}/preferences`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({
                sources: selectedSources,
                genres: selectedGenres
            })
        });
        
        if (response.ok) {
            // Reload titles and recommendations
            loadTitles();
            loadRecommendations();
            alert('Preferences updated successfully!');
        }
    } catch (error) {
        console.error('Error updating preferences:', error);
        alert('Error updating preferences');
    }
}

async function loadTitles() {
    try {
        showLoading('titlesLoading');
        const token = userSession.getIdToken().getJwtToken();
        const response = await fetch(`${config.apiEndpoint}/titles`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (response.ok) {
            const titles = await response.json();
            renderTitles(titles, 'titlesContainer');
        }
    } catch (error) {
        console.error('Error loading titles:', error);
    } finally {
        hideLoading('titlesLoading');
    }
}

async function loadRecommendations() {
    try {
        showLoading('recommendationsLoading');
        const token = userSession.getIdToken().getJwtToken();
        const response = await fetch(`${config.apiEndpoint}/recommendations`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (response.ok) {
            const recommendations = await response.json();
            renderTitles(recommendations, 'recommendationsContainer');
        }
    } catch (error) {
        console.error('Error loading recommendations:', error);
    } finally {
        hideLoading('recommendationsLoading');
    }
}

// UI rendering functions
function renderSourcesList() {
    const container = document.getElementById('sourcesList');
    container.innerHTML = sources.map(source => `
        <div class="form-check">
            <input class="form-check-input" type="checkbox" name="source" value="${source.id}" id="source_${source.id}">
            <label class="form-check-label" for="source_${source.id}">
                ${source.name}
            </label>
        </div>
    `).join('');
}

function renderGenresList() {
    const container = document.getElementById('genresList');
    container.innerHTML = genres.map(genre => `
        <div class="form-check">
            <input class="form-check-input" type="checkbox" name="genre" value="${genre.id}" id="genre_${genre.id}">
            <label class="form-check-label" for="genre_${genre.id}">
                ${genre.name}
            </label>
        </div>
    `).join('');
}

function updatePreferencesUI(preferences) {
    // Check sources
    preferences.sources.forEach(sourceId => {
        const checkbox = document.getElementById(`source_${sourceId}`);
        if (checkbox) checkbox.checked = true;
    });
    
    // Check genres
    preferences.genres.forEach(genreId => {
        const checkbox = document.getElementById(`genre_${genreId}`);
        if (checkbox) checkbox.checked = true;
    });
}

function renderTitles(titles, containerId) {
    const container = document.getElementById(containerId);
    
    if (titles.length === 0) {
        container.innerHTML = '<div class="col-12"><p class="text-muted">No titles found.</p></div>';
        return;
    }
    
    container.innerHTML = titles.map(title => `
        <div class="col-md-4 col-lg-3 mb-4">
            <div class="card title-card h-100" onclick="showTitleDetails('${title.id}', '${title.title}', '${title.plot_overview}', '${title.poster}', ${title.user_rating}, ${JSON.stringify(title.source_ids)}, ${JSON.stringify(title.genre_ids)})">
                <div class="position-relative">
                    <img src="${title.poster || 'https://via.placeholder.com/300x450?text=No+Image'}" 
                         class="card-img-top title-image" 
                         alt="${title.title}"
                         onerror="this.src='https://via.placeholder.com/300x450?text=No+Image'">
                    ${title.user_rating > 0 ? `<div class="rating-badge">${title.user_rating}/10</div>` : ''}
                </div>
                <div class="card-body">
                    <h6 class="card-title">${title.title}</h6>
                    <p class="card-text text-muted small">${title.plot_overview.substring(0, 100)}${title.plot_overview.length > 100 ? '...' : ''}</p>
                </div>
            </div>
        </div>
    `).join('');
}

function showTitleDetails(id, title, plot, poster, rating, sourceIds, genreIds) {
    document.getElementById('titleModalTitle').textContent = title;
    document.getElementById('titleModalImage').src = poster || 'https://via.placeholder.com/300x450?text=No+Image';
    document.getElementById('titleModalPlot').textContent = plot || 'No description available';
    document.getElementById('titleModalRating').textContent = rating > 0 ? `${rating}/10` : 'Not rated';
    
    // Get source and genre names
    const sourceNames = sourceIds.map(id => sources.find(s => s.id.toString() === id.toString())?.name || 'Unknown').join(', ');
    const genreNames = genreIds.map(id => genres.find(g => g.id.toString() === id.toString())?.name || 'Unknown').join(', ');
    
    document.getElementById('titleModalSources').textContent = sourceNames;
    document.getElementById('titleModalGenres').textContent = genreNames;
    
    // Show modal
    const modal = new bootstrap.Modal(document.getElementById('titleModal'));
    modal.show();
}

function showLoading(elementId) {
    document.getElementById(elementId).style.display = 'block';
}

function hideLoading(elementId) {
    document.getElementById(elementId).style.display = 'none';
}

// Utility function to get URL parameters
function getUrlParameter(name) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(name);
}

// Handle authentication callback
function handleAuthCallback() {
    const code = getUrlParameter('code');
    if (code) {
        // Handle the authentication code
        // This would typically involve exchanging the code for tokens
        console.log('Auth code received:', code);
    }
}

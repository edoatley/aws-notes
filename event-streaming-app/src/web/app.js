// Global variables
let currentUser = null;
let userSession = null;
let sources = [];
let genres = [];

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

async function initializeApp() {
    // Handle the authentication callback if present
    if (window.location.hash.includes('id_token')) {
        await handleAuthCallback();
    }

    // Check the user's authentication status
    await checkAuthStatus();

    // Set up event listeners after checking auth status
    setupEventListeners();
}

function setupEventListeners() {
    document.getElementById('loginBtn').addEventListener('click', showLogin);
    document.getElementById('logoutBtn').addEventListener('click', logout);
    document.getElementById('updatePreferencesBtn').addEventListener('click', updatePreferences);
    
    // Tab change events
    document.getElementById('titles-tab').addEventListener('click', () => loadTitles());
    document.getElementById('recommendations-tab').addEventListener('click', () => loadRecommendations());
}

function getCognitoAuth() {
    if (!config.userPoolDomain) {
        console.error("Cognito domain not configured!");
        return null;
    }
    // This constructor comes from the amazon-cognito-auth-js library
    return new AmazonCognitoIdentity.CognitoAuth({
        UserPoolId: config.userPoolId,
        ClientId: config.userPoolClientId,
        RedirectUriSignIn: window.location.origin,
        RedirectUriSignOut: window.location.origin,
        TokenScopesArray: ['openid', 'email', 'profile'],
        Domain: config.userPoolDomain
    });
}

function showLogin() {
    const auth = getCognitoAuth();
    if (auth) {
        auth.getSession();
    }
}

async function checkAuthStatus() {
    const auth = getCognitoAuth();
    if (!auth) return;

    return new Promise((resolve) => {
        auth.parseCognitoWebResponse(window.location.href);
        userSession = auth.getSignInUserSession();

        if (userSession && userSession.isValid()) {
            currentUser = userSession.getIdToken().payload;
            onUserAuthenticated();
        } else {
            onUserLoggedOut();
        }
        resolve();
    });
}

function handleAuthCallback() {
    return new Promise((resolve) => {
        const auth = getCognitoAuth();
        if (auth) {
            auth.parseCognitoWebResponse(window.location.href);
            userSession = auth.getSignInUserSession();
            if (userSession && userSession.isValid()) {
                // Clear the hash from the URL
                window.history.replaceState({}, document.title, window.location.pathname + window.location.search);
            }
        }
        resolve();
    });
}

function onUserAuthenticated() {
    document.getElementById('authSection').style.display = 'none';
    document.getElementById('mainContent').style.display = 'block';
    document.getElementById('loginBtn').style.display = 'none';
    document.getElementById('logoutBtn').style.display = 'block';
    
    // Load initial data
    loadSources();
    loadGenres();
    loadUserPreferences();
    loadTitles();
}

function onUserLoggedOut() {
    document.getElementById('mainContent').style.display = 'none';
    document.getElementById('authSection').style.display = 'block';
    document.getElementById('loginBtn').style.display = 'block';
    document.getElementById('logoutBtn').style.display = 'none';
}

function logout() {
    const auth = getCognitoAuth();
    if (auth) {
        auth.signOut();
    }
}

// API functions
async function makeApiRequest(path, method = 'GET', body = null) {
    try {
        const headers = {
            'Content-Type': 'application/json'
        };
        if (userSession) {
            const token = userSession.getIdToken().getJwtToken();
            headers['Authorization'] = `Bearer ${token}`;
        }

        const options = { method, headers };
        if (body) {
            options.body = JSON.stringify(body);
        }

        const response = await fetch(`${config.apiEndpoint}${path}`, options);
        if (!response.ok) {
            throw new Error(`API request failed with status ${response.status}`);
        }
        return await response.json();
    } catch (error) {
        console.error(`Error in API request to ${path}:`, error);
        throw error;
    }
}

async function loadSources() {
    try {
        sources = await makeApiRequest('/sources');
        renderSourcesList();
    } catch (error) {
        console.error('Error loading sources:', error);
    }
}

async function loadGenres() {
    try {
        genres = await makeApiRequest('/genres');
        renderGenresList();
    } catch (error) {
        console.error('Error loading genres:', error);
    }
}

async function loadUserPreferences() {
    try {
        const preferences = await makeApiRequest('/preferences');
        updatePreferencesUI(preferences);
    } catch (error) {
        console.error('Error loading user preferences:', error);
    }
}

async function updatePreferences() {
    const selectedSources = Array.from(document.querySelectorAll('input[name="source"]:checked')).map(cb => cb.value);
    const selectedGenres = Array.from(document.querySelectorAll('input[name="genre"]:checked')).map(cb => cb.value);
    
    try {
        await makeApiRequest('/preferences', 'PUT', { sources: selectedSources, genres: selectedGenres });
        alert('Preferences updated successfully!');
        // Reload titles and recommendations to reflect changes
        loadTitles();
        loadRecommendations();
    } catch (error) {
        alert('Error updating preferences');
    }
}

async function loadTitles() {
    try {
        showLoading('titlesLoading');
        const titles = await makeApiRequest('/titles');
        renderTitles(titles, 'titlesContainer');
    } catch (error) {
        console.error('Error loading titles:', error);
    } finally {
        hideLoading('titlesLoading');
    }
}

async function loadRecommendations() {
    try {
        showLoading('recommendationsLoading');
        const recommendations = await makeApiRequest('/recommendations');
        renderTitles(recommendations, 'recommendationsContainer');
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
    if (!preferences) return;
    // Check sources
    if (preferences.sources) {
        preferences.sources.forEach(sourceId => {
            const checkbox = document.getElementById(`source_${sourceId}`);
            if (checkbox) checkbox.checked = true;
        });
    }
    // Check genres
    if (preferences.genres) {
        preferences.genres.forEach(genreId => {
            const checkbox = document.getElementById(`genre_${genreId}`);
            if (checkbox) checkbox.checked = true;
        });
    }
}

function renderTitles(titles, containerId) {
    const container = document.getElementById(containerId);
    
    if (!titles || titles.length === 0) {
        container.innerHTML = '<div class="col-12"><p class="text-muted">No titles found.</p></div>';
        return;
    }
    
    container.innerHTML = titles.map(title => `
        <div class="col-md-4 col-lg-3 mb-4">
            <div class="card title-card h-100" onclick="showTitleDetails(${JSON.stringify(title)})">
                <div class="position-relative">
                    <img src="${title.poster || 'https://via.placeholder.com/300x450?text=No+Image'}" 
                         class="card-img-top title-image" 
                         alt="${title.title}"
                         onerror="this.src='https://via.placeholder.com/300x450?text=No+Image'">
                    ${title.user_rating > 0 ? `<div class="rating-badge">${title.user_rating}/10</div>` : ''}
                </div>
                <div class="card-body">
                    <h6 class="card-title">${title.title}</h6>
                    <p class="card-text text-muted small">${(title.plot_overview || '').substring(0, 100)}${title.plot_overview && title.plot_overview.length > 100 ? '...' : ''}</p>
                </div>
            </div>
        </div>
    `).join('');
}

function showTitleDetails(title) {
    document.getElementById('titleModalTitle').textContent = title.title;
    document.getElementById('titleModalImage').src = title.poster || 'https://via.placeholder.com/300x450?text=No+Image';
    document.getElementById('titleModalPlot').textContent = title.plot_overview || 'No description available';
    document.getElementById('titleModalRating').textContent = title.user_rating > 0 ? `${title.user_rating}/10` : 'Not rated';
    
    const sourceNames = (title.source_ids || []).map(id => sources.find(s => s.id.toString() === id.toString())?.name || 'Unknown').join(', ');
    const genreNames = (title.genre_ids || []).map(id => genres.find(g => g.id.toString() === id.toString())?.name || 'Unknown').join(', ');
    
    document.getElementById('titleModalSources').textContent = sourceNames;
    document.getElementById('titleModalGenres').textContent = genreNames;
    
    const modal = new bootstrap.Modal(document.getElementById('titleModal'));
    modal.show();
}

function showLoading(elementId) {
    document.getElementById(elementId).style.display = 'block';
}

function hideLoading(elementId) {
    document.getElementById(elementId).style.display = 'none';
}

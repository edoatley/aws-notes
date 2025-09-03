function parseJwt(token) {
    try {
        return JSON.parse(atob(token.split('.')[1]));
    } catch (e) {
        return null;
    }
}

function handleLogin() {
    const cognitoDomain = window.appConfig.Auth.oauth.domain;
    const clientId = window.appConfig.Auth.userPoolClientId;
    const redirectUri = window.location.origin + "/index.html";
    const responseType = "token";
    const scope = window.appConfig.Auth.oauth.scope.join(' ');

    const url = `https://${cognitoDomain}/login?response_type=${responseType}&client_id=${clientId}&redirect_uri=${redirectUri}&scope=${scope}`;
    window.location.assign(url);
}

function handleLogout() {
    localStorage.removeItem('id_token');
    const cognitoDomain = window.appConfig.Auth.oauth.domain;
    const clientId = window.appConfig.Auth.userPoolClientId;
    const redirectUri = window.location.origin + "/index.html";
    const logoutUrl = `https://${cognitoDomain}/logout?client_id=${clientId}&logout_uri=${redirectUri}`;
    window.location.assign(logoutUrl);
}

let sources = [];
let genres = [];
let isAppInitialized = false;

function startApp() {
    if (isAppInitialized) return;
    isAppInitialized = true;

    console.log("Authenticated: Starting application...");
    setupAppEventListeners();

    loadSources();
    loadGenres();
    loadUserPreferences();
    loadTitles();
}

function setupAppEventListeners() {
    document.getElementById('updatePreferencesBtn').addEventListener('click', updatePreferences);
    document.getElementById('titles-tab').addEventListener('click', () => loadTitles());
    document.getElementById('recommendations-tab').addEventListener('click', () => loadRecommendations());
}

async function makeApiRequest(path, method = 'GET', body = null) {
    try {
        const headers = {
            'Content-Type': 'application/json'
        };

        if (window.idToken) {
            headers['Authorization'] = `Bearer ${window.idToken}`;
        }

        const options = { method, headers };
        if (body) {
            options.body = JSON.stringify(body);
        }

        const response = await fetch(`${window.appConfig.ApiEndpoint}${path}`, options);

        if (!response.ok) {
            throw new Error(`API request failed with status ${response.status}`);
        }

        const contentType = response.headers.get("content-type");
        if (contentType && contentType.indexOf("application/json") !== -1) {
            return await response.json();
        } else {
            return;
        }
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
        if (preferences) {
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
        await makeApiRequest('/preferences', 'PUT', { sources: selectedSources, genres: selectedGenres });
        alert('Preferences updated successfully!');
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

function renderSourcesList() {
    const container = document.getElementById('sourcesList');
    if(container) container.innerHTML = sources.map(source => `
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
    if(container) container.innerHTML = genres.map(genre => `
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
    if (preferences.sources) {
        preferences.sources.forEach(sourceId => {
            const checkbox = document.getElementById(`source_${sourceId}`);
            if (checkbox) checkbox.checked = true;
        });
    }
    if (preferences.genres) {
        preferences.genres.forEach(genreId => {
            const checkbox = document.getElementById(`genre_${genreId}`);
            if (checkbox) checkbox.checked = true;
        });
    }
}

function renderTitles(titles, containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;

    if (!titles || titles.length === 0) {
        container.innerHTML = '<div class="col-12"><p class="text-muted">No titles found.</p></div>';
        return;
    }

    container.innerHTML = titles.map(title => `
        <div class="col-md-4 col-lg-3 mb-4">
            <div class="card title-card h-100" onclick='showTitleDetails(${JSON.stringify(title).replace(/'/g, "&apos;")})'>
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
    const el = document.getElementById(elementId);
    if (el) el.style.display = 'block';
}

function hideLoading(elementId) {
    const el = document.getElementById(elementId);
    if (el) el.style.display = 'none';
}

function initializeApp() {
    const path = window.location.pathname;

    if (path.endsWith('login.html')) {
        const loginButton = document.getElementById('loginPageLoginBtn');
        if (loginButton) {
            loginButton.addEventListener('click', handleLogin);
        }
        return;
    }

    const loginBtn = document.getElementById('loginBtn');
    const logoutBtn = document.getElementById('logoutBtn');
    const authSection = document.getElementById('authSection');
    const mainContent = document.getElementById('mainContent');

    if (!loginBtn) return; // We are on a page without login buttons

    loginBtn.addEventListener('click', handleLogin);
    logoutBtn.addEventListener('click', handleLogout);

    const hash = window.location.hash.substring(1);
    const params = new URLSearchParams(hash);
    const id_token = params.get('id_token');

    if (id_token) {
        localStorage.setItem('id_token', id_token);
        window.history.replaceState({}, document.title, window.location.pathname + window.location.search);
    }

    const stored_token = localStorage.getItem('id_token');

    if (stored_token) {
        const decodedToken = parseJwt(stored_token);
        if (decodedToken && decodedToken.exp * 1000 > Date.now()) {
            authSection.style.display = 'none';
            mainContent.style.display = 'block';
            loginBtn.style.display = 'none';
            logoutBtn.style.display = 'block';
            window.idToken = stored_token;
            startApp();
        } else {
            localStorage.removeItem('id_token');
            authSection.style.display = 'block';
            mainContent.style.display = 'none';
            loginBtn.style.display = 'block';
            logoutBtn.style.display = 'none';
        }
    } else {
        authSection.style.display = 'block';
        mainContent.style.display = 'none';
        loginBtn.style.display = 'block';
        logoutBtn.style.display = 'none';
    }
}

function waitForConfigAndInitialize() {
    const interval = setInterval(() => {
        if (window.appConfig) {
            clearInterval(interval);
            initializeApp();
        }
    }, 50);
}

document.addEventListener('DOMContentLoaded', waitForConfigAndInitialize);

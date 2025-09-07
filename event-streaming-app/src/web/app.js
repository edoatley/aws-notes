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

async function startApp() {
    if (isAppInitialized) return;
    isAppInitialized = true;

    console.log("Authenticated: Starting application...");
    setupAppEventListeners();
    
    // Set the default page view
    showPage('titles');
    
    // Fetch all reference data first. This prevents a race condition where
    // we try to check preference boxes that haven't been rendered yet.
    await Promise.all([loadSources(), loadGenres()]);
    
    // Then fetch user preferences, which will trigger the rendering of the preferences page.
    await loadUserPreferences();
    
    // Now load the content.
    loadTitles();
}

function showPage(pageName) {
    // Hide all pages
    document.getElementById('titlesPage').style.display = 'none';
    document.getElementById('preferencesPage').style.display = 'none';

    // Deactivate all nav links
    document.getElementById('nav-titles').classList.remove('active');
    document.getElementById('nav-preferences').classList.remove('active');

    // Show the selected page and activate the nav link
    if (pageName === 'titles') {
        document.getElementById('titlesPage').style.display = 'block';
        document.getElementById('nav-titles').classList.add('active');
    } else if (pageName === 'preferences') {
        document.getElementById('preferencesPage').style.display = 'block';
        document.getElementById('nav-preferences').classList.add('active');
    }
}

function setupAppEventListeners() {
    document.getElementById('updatePreferencesBtn').addEventListener('click', updatePreferences);
    document.getElementById('titles-tab').addEventListener('click', () => loadTitles());
    document.getElementById('recommendations-tab').addEventListener('click', () => loadRecommendations());

    // Add navigation event listeners
    document.getElementById('nav-titles').addEventListener('click', (e) => {
        e.preventDefault();
        showPage('titles');
    });
    document.getElementById('nav-preferences').addEventListener('click', (e) => {
        e.preventDefault();
        showPage('preferences');
    });
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

        const contentType = response.headers.get("content-type");
        const isJson = contentType && contentType.indexOf("application/json") !== -1;

        if (!response.ok) {
            let errorBody = { message: `API request failed with status ${response.status}` };
            if (isJson) {
                try {
                    errorBody = await response.json();
                } catch (e) { /* Ignore if body isn't valid JSON */ }
            }
            const error = new Error(errorBody.error || errorBody.message || `API request failed with status ${response.status}`);
            error.response = response; // Attach response for further inspection if needed
            throw error;
        }

        if (isJson) {
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
    } catch (error) {
        console.error('Error loading sources:', error);
    }
}

async function loadGenres() {
    try {
        genres = await makeApiRequest('/genres');
    } catch (error) {
        console.error('Error loading genres:', error);
    }
}

async function loadUserPreferences() {
    try {
        const preferences = await makeApiRequest('/preferences');
        if (preferences) {
            renderPreferences(sources, genres, preferences);
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
        // Re-render the preferences UI to move items between selected/available lists
        await loadUserPreferences();
        loadTitles();
        loadRecommendations();
    } catch (error) {
        alert(`Error updating preferences: ${error.message}`);
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

function renderPreferences(allSources, allGenres, userPreferences) {
    const renderList = (items, selectedIds, selectedContainerId, availableContainerId, type) => {
        const selectedContainer = document.getElementById(selectedContainerId);
        const availableContainer = document.getElementById(availableContainerId);

        if (!selectedContainer || !availableContainer) return;

        let selectedHtml = '';
        let availableHtml = '';

        items.forEach(item => {
            const isSelected = selectedIds.includes(item.id.toString());
            const checkboxHtml = `
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" name="${type}" value="${item.id}" id="${type}_${item.id}" ${isSelected ? 'checked' : ''}>
                    <label class="form-check-label" for="${type}_${item.id}">
                        ${item.name}
                    </label>
                </div>
            `;
            if (isSelected) {
                selectedHtml += checkboxHtml;
            } else {
                availableHtml += checkboxHtml;
            }
        });

        selectedContainer.innerHTML = selectedHtml || `<p class="text-muted small">No ${type}s selected.</p>`;
        availableContainer.innerHTML = availableHtml || `<p class="text-muted small">All available ${type}s are selected.</p>`;
    };

    renderList(allSources, userPreferences.sources || [], 'selectedSourcesList', 'availableSourcesList', 'source');
    renderList(allGenres, userPreferences.genres || [], 'selectedGenresList', 'availableGenresList', 'genre');
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

async function initializeApp() {
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
    const mainNav = document.getElementById('mainNav');
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
            if (mainNav) mainNav.style.display = 'flex';
            window.idToken = stored_token;
            await startApp();
        } else {
            localStorage.removeItem('id_token');
            authSection.style.display = 'block';
            mainContent.style.display = 'none';
            loginBtn.style.display = 'block';
            logoutBtn.style.display = 'none';
            if (mainNav) mainNav.style.display = 'none';
        }
    } else {
        authSection.style.display = 'block';
        mainContent.style.display = 'none';
        loginBtn.style.display = 'block';
        logoutBtn.style.display = 'none';
        if (mainNav) mainNav.style.display = 'none';
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

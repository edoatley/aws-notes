#!/bin/bash

# Script to update the website configuration with actual CloudFormation output values
# Usage: ./update_website_config.sh <stack-name> <aws-profile> <aws-region>

set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <stack-name> <aws-profile> <aws-region>"
    echo "Example: $0 uktv-event-streaming-app streaming us-east-1"
    exit 1
fi

STACK_NAME=$1
PROFILE=$2
REGION=$3

echo "🔧 Updating website configuration for stack: $STACK_NAME"
echo "📁 Profile: $PROFILE"
echo "🌍 Region: $REGION"

# Get CloudFormation outputs
echo "📋 Getting CloudFormation outputs..."
USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
    --output text)

USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
    --output text)

WEB_API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`WebApiEndpoint`].OutputValue' \
    --output text)

USER_PREFERENCES_API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPreferencesApiEndpoint`].OutputValue' \
    --output text)

WEBSITE_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucket`].OutputValue' \
    --output text)

echo "✅ Retrieved configuration values:"
echo "   User Pool ID: $USER_POOL_ID"
echo "   User Pool Client ID: $USER_POOL_CLIENT_ID"
echo "   Web API Endpoint: $WEB_API_ENDPOINT"
echo "   User Preferences API Endpoint: $USER_PREFERENCES_API_ENDPOINT"
echo "   Website Bucket: $WEBSITE_BUCKET"

# Create updated app.js with actual values
echo "📝 Creating updated app.js with actual configuration values..."
cat > app.js << EOF
const config = {
    region: '$REGION',
    userPoolId: '$USER_POOL_ID',
    userPoolClientId: '$USER_POOL_CLIENT_ID',
    apiEndpoint: '$WEB_API_ENDPOINT',
    preferencesApiEndpoint: '$USER_PREFERENCES_API_ENDPOINT'
};
let currentUser = null; let userPool = null; let userSession = null; let sources = []; let genres = [];
document.addEventListener('DOMContentLoaded', function() { initializeApp(); setupEventListeners(); });
function initializeApp() { checkAuthStatus(); loadSources(); loadGenres(); }
function setupEventListeners() {
    document.getElementById('loginBtn').addEventListener('click', showLogin);
    document.getElementById('logoutBtn').addEventListener('click', logout);
    document.getElementById('updatePreferencesBtn').addEventListener('click', updatePreferences);
    document.getElementById('titles-tab').addEventListener('click', () => loadTitles());
    document.getElementById('recommendations-tab').addEventListener('click', () => loadRecommendations());
}
function showLogin() { document.getElementById('authSection').style.display = 'block'; document.getElementById('mainContent').style.display = 'none'; }
function checkAuthStatus() {
    const session = getCurrentSession();
    if (session && session.isValid()) { userSession = session; currentUser = session.username; onUserAuthenticated(); } else { showLogin(); }
}
function onUserAuthenticated() {
    document.getElementById('authSection').style.display = 'none';
    document.getElementById('mainContent').style.display = 'block';
    document.getElementById('loginBtn').style.display = 'none';
    document.getElementById('logoutBtn').style.display = 'block';
    loadUserPreferences(); loadTitles();
}
function logout() {
    if (userSession) { userSession.signOut(); }
    currentUser = null; userSession = null;
    document.getElementById('mainContent').style.display = 'none';
    document.getElementById('loginBtn').style.display = 'block';
    document.getElementById('logoutBtn').style.display = 'none';
    showLogin();
}
function getCurrentSession() {
    if (!userPool) {
        userPool = new AmazonCognitoIdentity.CognitoUserPool({
            UserPoolId: config.userPoolId, ClientId: config.userPoolClientId
        });
    }
    const cognitoUser = userPool.getCurrentUser();
    if (cognitoUser) {
        return new Promise((resolve, reject) => {
            cognitoUser.getSession((err, session) => { if (err) { reject(err); } else { resolve(session); } });
        });
    }
    return null;
}
async function loadSources() {
    try {
        const response = await fetch(`${config.preferencesApiEndpoint}/sources`);
        if (response.ok) { sources = await response.json(); renderSourcesList(); }
    } catch (error) { console.error('Error loading sources:', error); }
}
async function loadGenres() {
    try {
        const response = await fetch(`${config.preferencesApiEndpoint}/genres`);
        if (response.ok) { genres = await response.json(); renderGenresList(); }
    } catch (error) { console.error('Error loading genres:', error); }
}
async function loadUserPreferences() {
    try {
        const token = userSession.getIdToken().getJwtToken();
        const response = await fetch(`${config.preferencesApiEndpoint}/preferences`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        if (response.ok) { const preferences = await response.json(); updatePreferencesUI(preferences); }
    } catch (error) { console.error('Error loading user preferences:', error); }
}
async function updatePreferences() {
    const selectedSources = Array.from(document.querySelectorAll('input[name="source"]:checked')).map(cb => cb.value);
    const selectedGenres = Array.from(document.querySelectorAll('input[name="genre"]:checked')).map(cb => cb.value);
    try {
        const token = userSession.getIdToken().getJwtToken();
        const response = await fetch(`${config.preferencesApiEndpoint}/preferences`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
            body: JSON.stringify({ sources: selectedSources, genres: selectedGenres })
        });
        if (response.ok) { loadTitles(); loadRecommendations(); alert('Preferences updated successfully!'); }
    } catch (error) { console.error('Error updating preferences:', error); alert('Error updating preferences'); }
}
async function loadTitles() {
    try {
        showLoading('titlesLoading');
        const token = userSession.getIdToken().getJwtToken();
        const response = await fetch(`${config.apiEndpoint}/titles`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        if (response.ok) { const titles = await response.json(); renderTitles(titles, 'titlesContainer'); }
    } catch (error) { console.error('Error loading titles:', error); } finally { hideLoading('titlesLoading'); }
}
async function loadRecommendations() {
    try {
        showLoading('recommendationsLoading');
        const token = userSession.getIdToken().getJwtToken();
        const response = await fetch(`${config.apiEndpoint}/recommendations`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        if (response.ok) { const recommendations = await response.json(); renderTitles(recommendations, 'recommendationsContainer'); }
    } catch (error) { console.error('Error loading recommendations:', error); } finally { hideLoading('recommendationsLoading'); }
}
function renderSourcesList() {
    const container = document.getElementById('sourcesList');
    container.innerHTML = sources.map(source => `
        <div class="form-check">
            <input class="form-check-input" type="checkbox" name="source" value="${source.id}" id="source_${source.id}">
            <label class="form-check-label" for="source_${source.id}">${source.name}</label>
        </div>
    `).join('');
}
function renderGenresList() {
    const container = document.getElementById('genresList');
    container.innerHTML = genres.map(genre => `
        <div class="form-check">
            <input class="form-check-input" type="checkbox" name="genre" value="${genre.id}" id="genre_${genre.id}">
            <label class="form-check-label" for="genre_${genre.id}">${genre.name}</label>
        </div>
    `).join('');
}
function updatePreferencesUI(preferences) {
    preferences.sources.forEach(sourceId => {
        const checkbox = document.getElementById(`source_${sourceId}`);
        if (checkbox) checkbox.checked = true;
    });
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
    const sourceNames = sourceIds.map(id => sources.find(s => s.id.toString() === id.toString())?.name || 'Unknown').join(', ');
    const genreNames = genreIds.map(id => genres.find(g => g.id.toString() === id.toString())?.name || 'Unknown').join(', ');
    document.getElementById('titleModalSources').textContent = sourceNames;
    document.getElementById('titleModalGenres').textContent = genreNames;
    const modal = new bootstrap.Modal(document.getElementById('titleModal'));
    modal.show();
}
function showLoading(elementId) { document.getElementById(elementId).style.display = 'block'; }
function hideLoading(elementId) { document.getElementById(elementId).style.display = 'none'; }
EOF

echo "✅ Created updated app.js"

# Upload the updated app.js to S3
echo "📤 Uploading updated app.js to S3..."
aws s3 cp app.js "s3://$WEBSITE_BUCKET/" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --content-type "application/javascript" \
    --acl public-read

echo "✅ Updated app.js uploaded to S3"

# Clean up local file
rm app.js

echo ""
echo "🎉 Website configuration updated successfully!"
echo "🌐 Your website should now work with the correct configuration values."
echo ""
echo "📝 Configuration values used:"
echo "   Region: $REGION"
echo "   User Pool ID: $USER_POOL_ID"
echo "   User Pool Client ID: $USER_POOL_CLIENT_ID"
echo "   Web API Endpoint: $WEB_API_ENDPOINT"
echo "   User Preferences API Endpoint: $USER_PREFERENCES_API_ENDPOINT"

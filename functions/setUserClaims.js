const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Cloud Function: setUserClaims
 *
 * HTTP POST endpoint to set custom claims on a user.
 * Only callable by super_admin users.
 *
 * Request body:
 * {
 *   "uid": "user_uid_here",
 *   "tenant_id": "tenant_001",
 *   "role": "dueno" | "recepcionista" | "estilista"
 * }
 *
 * Response:
 * {
 *   "success": true,
 *   "message": "Custom claims set successfully"
 * }
 *
 * Error response:
 * {
 *   "success": false,
 *   "error": "error message"
 * }
 */
const setUserClaims = functions.https.onRequest(async (request, response) => {
  // Enable CORS for testing (restrict in production)
  response.set('Access-Control-Allow-Origin', '*');
  response.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight requests
  if (request.method === 'OPTIONS') {
    response.status(200).send('');
    return;
  }

  // Only allow POST requests
  if (request.method !== 'POST') {
    return response.status(405).json({
      success: false,
      error: 'Method not allowed. Use POST.',
    });
  }

  try {
    // Extract request body
    const { uid, tenant_id, role } = request.body;

    // Validate required fields
    if (!uid || !tenant_id || !role) {
      return response.status(400).json({
        success: false,
        error:
          'Missing required fields: uid, tenant_id, role',
      });
    }

    // Validate role
    const validRoles = ['dueno', 'recepcionista', 'estilista'];
    if (!validRoles.includes(role)) {
      return response.status(400).json({
        success: false,
        error: `Invalid role. Must be one of: ${validRoles.join(', ')}`,
      });
    }

    // Verify caller is super_admin (from Authorization header)
    const idToken = request.headers.authorization?.split('Bearer ')[1];
    if (!idToken) {
      return response.status(401).json({
        success: false,
        error: 'Missing Authorization header with Bearer token.',
      });
    }

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      return response.status(401).json({
        success: false,
        error: `Invalid or expired token: ${error.message}`,
      });
    }

    // Check if caller has super_admin role
    const callerRole = decodedToken.role || decodedToken.custom_role;
    if (callerRole !== 'super_admin') {
      return response.status(403).json({
        success: false,
        error: 'Only super_admin users can call this function.',
      });
    }

    // Set custom claims on user
    const customClaims = {
      tenant_id,
      role,
    };

    await admin.auth().setCustomUserClaims(uid, customClaims);

    // Success response
    return response.status(200).json({
      success: true,
      message: 'Custom claims set successfully',
      data: {
        uid,
        claims: customClaims,
      },
    });
  } catch (error) {
    console.error('Error setting custom claims:', error);
    return response.status(500).json({
      success: false,
      error: `Internal server error: ${error.message}`,
    });
  }
});

module.exports = { setUserClaims };

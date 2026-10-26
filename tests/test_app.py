import pytest
from app import app, init_db

# -------------------------------------------------------------------------
# Fixtures & Helper Functions
# -------------------------------------------------------------------------

@pytest.fixture
def client(tmp_path):
    """
    Pytest fixture that creates a new, isolated test client for every test.
    It uses tmp_path to create a temporary database, ensuring tests do not 
    interfere with each other or the production database.
    """
    app.config.update(
        TESTING=True,
        DATABASE=str(tmp_path / 'test.db'),
        SECRET_KEY='test-secret'
    )
    init_db() # Initialise the empty temp database
    return app.test_client()

def token(client):
    """
    Helper function to extract the CSRF token from the session.
    This is required to successfully submit POST requests in the tests.
    """
    with client.session_transaction() as sess:
        return sess['_csrf']

def register(client, email='person@example.com'):
    """
    Helper function to register a user.
    First GETs the registration page to set the CSRF token in the session,
    then POSTs the new user data.
    """
    client.get('/register')
    return client.post('/register', data={
        '_csrf': token(client),
        'name': 'Person',
        'email': email,
        'password': 'SecurePassword123'
    }, follow_redirects=True)

# -------------------------------------------------------------------------
# Automated Test Cases
# -------------------------------------------------------------------------

def test_register_create_and_comment(client):
    """
    TC-01, TC-02, TC-06: Tests the core customer workflow.
    Verifies registration, ticket creation, and posting a comment.
    """
    # 1. Verify registration page loads
    assert b'Create your account' in client.get('/register').data
    
    # 2. Register and verify redirect to dashboard
    assert b'Ticket dashboard' in register(client).data
    
    # 3. Create a new ticket
    client.get('/tickets/new')
    r = client.post('/tickets/new', data={
        '_csrf': token(client),
        'title': 'Billing error',
        'description': 'Incorrect invoice',
        'category': 'Billing',
        'priority': 'High'
    }, follow_redirects=True)
    
    # Verify ticket was created and displayed
    assert b'Billing error' in r.data
    
    # 4. Post a comment on the ticket
    r = client.post('/tickets/1/comment', data={
        '_csrf': token(client),
        'body': 'Please investigate'
    }, follow_redirects=True)
    
    # Verify comment appears
    assert b'Please investigate' in r.data


def test_login_and_access_controls(client):
    """
    TC-09, TC-10, TC-13: Tests security, role restrictions, and CSRF.
    Verifies a customer cannot update tickets, CSRF is enforced, 
    and logout/login works correctly.
    """
    # Setup: Register user and create a ticket
    register(client)
    client.get('/tickets/new')
    client.post('/tickets/new', data={
        '_csrf': token(client),
        'title': 'A', 'description': 'B', 
        'category': 'General', 'priority': 'Low'
    })
    
    # Security Test 1: Customer tries to update a ticket (Staff-only action)
    # Expect a 403 Forbidden
    assert client.post('/tickets/1/update', data={
        '_csrf': token(client),
        'status': 'Closed',
        'priority': 'High',
        'assigned_to': ''
    }).status_code == 403
    
    # Security Test 2: CSRF Protection
    # Attempt POST without a CSRF token, expect a 400 Bad Request
    assert client.post('/tickets/1/comment', data={
        'body': 'Missing token'
    }).status_code == 400
    
    # Test Logout
    client.post('/logout', data={'_csrf': token(client)})
    # Verify unauthenticated access redirects to login (302)
    assert client.get('/dashboard').status_code == 302
    
    # Test Login
    client.get('/login')
    r = client.post('/login', data={
        '_csrf': token(client),
        'email': 'person@example.com',
        'password': 'SecurePassword123'
    }, follow_redirects=True)
    assert b'Ticket dashboard' in r.data


def test_customer_isolation(client):
    """
    TC-11: Critical Security Test for Data Isolation.
    Verifies that Customer 2 cannot access Customer 1's ticket.
    """
    # Setup: Customer 1 registers and creates a ticket
    register(client, 'one@example.com')
    client.get('/tickets/new')
    client.post('/tickets/new', data={
        '_csrf': token(client),
        'title': 'Private',
        'description': 'Private issue',
        'category': 'General',
        'priority': 'Low'
    })
    
    # Log out Customer 1
    client.post('/logout', data={'_csrf': token(client)})
    
    # Setup: Customer 2 registers
    register(client, 'two@example.com')
    
    # Test 1: Customer 2 tries to directly access Customer 1's ticket by ID
    # Expect a 403 Forbidden
    assert client.get('/tickets/1').status_code == 403
    
    # Test 2: Customer 2 views their dashboard
    # Verify Customer 1's private ticket does not appear in the list
    assert b'Private issue' not in client.get('/dashboard').data
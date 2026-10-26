import pytest
from app import app, init_db

@pytest.fixture
def client(tmp_path):
    app.config.update(TESTING=True,DATABASE=str(tmp_path/'test.db'),SECRET_KEY='test-secret')
    init_db()
    return app.test_client()

def token(client):
    with client.session_transaction() as sess: return sess['_csrf']

def register(client,email='person@example.com'):
    client.get('/register')
    return client.post('/register',data={'_csrf':token(client),'name':'Person','email':email,'password':'SecurePassword123'},follow_redirects=True)

def test_register_create_and_comment(client):
    assert b'Create your account' in client.get('/register').data
    assert b'Ticket dashboard' in register(client).data
    client.get('/tickets/new')
    r=client.post('/tickets/new',data={'_csrf':token(client),'title':'Billing error','description':'Incorrect invoice','category':'Billing','priority':'High'},follow_redirects=True)
    assert b'Billing error' in r.data
    r=client.post('/tickets/1/comment',data={'_csrf':token(client),'body':'Please investigate'},follow_redirects=True)
    assert b'Please investigate' in r.data

def test_login_and_access_controls(client):
    register(client)
    client.get('/tickets/new')
    client.post('/tickets/new',data={'_csrf':token(client),'title':'A','description':'B','category':'General','priority':'Low'})
    assert client.post('/tickets/1/update',data={'_csrf':token(client),'status':'Closed','priority':'High','assigned_to':''}).status_code==403
    assert client.post('/tickets/1/comment',data={'body':'Missing token'}).status_code==400
    client.post('/logout',data={'_csrf':token(client)})
    assert client.get('/dashboard').status_code==302
    client.get('/login')
    r=client.post('/login',data={'_csrf':token(client),'email':'person@example.com','password':'SecurePassword123'},follow_redirects=True)
    assert b'Ticket dashboard' in r.data

def test_customer_isolation(client):
    register(client,'one@example.com')
    client.get('/tickets/new')
    client.post('/tickets/new',data={'_csrf':token(client),'title':'Private','description':'Private issue','category':'General','priority':'Low'})
    client.post('/logout',data={'_csrf':token(client)})
    register(client,'two@example.com')
    assert client.get('/tickets/1').status_code==403
    assert b'Private issue' not in client.get('/dashboard').data

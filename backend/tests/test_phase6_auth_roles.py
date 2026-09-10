import pytest
from fastapi.testclient import TestClient
from backend.app.main import app

client = TestClient(app)

def test_collector_login_success():
    response = client.post(
        "/api/auth/login",
        json={"identifier": "9842100001", "password": "password123", "role": "COLLECTOR"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "COLLECTOR"
    assert data["access_token"].startswith("ecoscrap_collector_")
    assert data["user"]["name"] == "Murugan K."
    assert data["profile"]["profile_type"] == "COLLECTOR"
    assert data["profile"]["collector_code"] == "COL-TN-019284"
    assert data["profile"]["trust_score"] == 94.5

def test_recycler_login_success():
    response = client.post(
        "/api/auth/login",
        json={"identifier": "9842100010", "password": "password123", "role": "RECYCLER"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "RECYCLER"
    assert data["access_token"].startswith("ecoscrap_recycler_")
    assert data["profile"]["profile_type"] == "RECYCLER"
    assert data["profile"]["registration_no"] == "CPCB-TN-REC-2024-8812"
    assert data["profile"]["reliability_score"] == 96.0

def test_admin_login_success():
    response = client.post(
        "/api/auth/login",
        json={"identifier": "admin@ecoscrap.in", "password": "admin123", "role": "ADMIN"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "ADMIN"
    assert data["access_token"].startswith("ecoscrap_admin_")
    assert data["profile"]["profile_type"] == "ADMIN"
    assert data["profile"]["officer_id"] == "CPCB-TN-OFFICER-001"

def test_login_wrong_password_rejected():
    response = client.post(
        "/api/auth/login",
        json={"identifier": "9842100001", "password": "invalid_pass_XYZ"}
    )
    assert response.status_code == 401
    assert "Invalid" in response.json()["detail"]

def test_login_role_mismatch_rejected():
    # Attempting to login with Collector credentials under Recycler role filter
    response = client.post(
        "/api/auth/login",
        json={"identifier": "9842100001", "password": "password123", "role": "RECYCLER"}
    )
    assert response.status_code == 403
    assert "registered as a COLLECTOR" in response.json()["detail"]

def test_get_demo_users_endpoint():
    response = client.get("/api/auth/demo-users")
    assert response.status_code == 200
    demo_list = response.json()
    assert len(demo_list) == 3
    roles = [d["role"] for d in demo_list]
    assert "COLLECTOR" in roles
    assert "RECYCLER" in roles
    assert "ADMIN" in roles

def test_register_new_collector():
    import random
    rand_num = random.randint(100000, 999999)
    phone = f"9842{rand_num}"
    payload = {
        "name": "Ramu Scrap Dealer",
        "phone": phone,
        "email": f"ramu_{rand_num}@ecoscrap.in",
        "password": "securePass456",
        "role": "COLLECTOR",
        "language": "ta"
    }
    response = client.post("/api/auth/register", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "COLLECTOR"
    assert data["user"]["name"] == "Ramu Scrap Dealer"
    assert data["profile"]["profile_type"] == "COLLECTOR"
    assert data["profile"]["collector_code"].startswith("COL-TN-")

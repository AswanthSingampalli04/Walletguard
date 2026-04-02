from flask import Flask, request, jsonify
import numpy as np
import joblib
import pandas as pd
from flask_cors import CORS
import requests

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# OCR Service URL (running on port 5001)
OCR_SERVICE_URL = "http://localhost:5001"

# -------------------------
# Load all trained models
# -------------------------

# For clustering model
nb_model = joblib.load("naive_bayes_model.pkl")
encoder = joblib.load("encoder.pkl")
scaler = joblib.load("scaler.pkl")

# For random-forest prediction
model = joblib.load("random_forest_model (3).pkl")

# Correct category feature names (must match training)
expected_features = ["Credit/Debit", "Transaction Type"]


# -------------------------------------------------
# 🔹 Endpoint 1: Predict Next Month Expense
# -------------------------------------------------
@app.route("/predict_expense", methods=["POST"])
def predict_expense():
    try:
        # Parse JSON input
        data = request.get_json()
        print("🔹 Received Request: ", data)

        # Build input DataFrame with correct feature names
        input_data = pd.DataFrame([[
            #float(data["person"]),
            float(data["month_1"]),  # → "2020"
            float(data["month_2"]),  # → "2021"
            float(data["month_3"])   # → "2022"
        ]], columns=["2020", "2021", "2022"])

        print("🔹 Transformed Input Data:\n", input_data)

        # Model prediction
        predicted_value = model.predict(input_data)[0]
        print(f"✅ Prediction: {predicted_value}")

        return jsonify({"predicted_next_month": round(predicted_value, 2)})

    except Exception as e:
        print("❌ Error processing request: ", str(e))
        return jsonify({"error": str(e)}), 400


# -------------------------------------------------
# 🔹 Endpoint 2: Predict Cluster (Naive Bayes)
# -------------------------------------------------
@app.route("/predict", methods=["POST"])
def predict_cluster():
    try:
        data = request.get_json()
        amount = float(data["amount"])
        credit_debit = data["credit_debit"]
        transaction_type = data["transaction_type"]

        print("Received Input Data:", data)

        # Create category DataFrame
        sample_category_df = pd.DataFrame([[credit_debit, transaction_type]], columns=expected_features)

        # Encode categories safely
        try:
            sample_category_encoded = encoder.transform(sample_category_df)
        except ValueError as e:
            print("⚠️ Warning:", str(e))
            return jsonify({"error": "Unknown category in input. Please retrain encoder with more data."}), 400

        # Scale numeric amount
        sample_numeric_scaled = scaler.transform(np.array([[amount]]))

        # Combine all features
        sample_final = np.hstack((sample_numeric_scaled, sample_category_encoded))

        # Predict cluster
        predicted_cluster = nb_model.predict(sample_final)

        return jsonify({"predicted_cluster": int(predicted_cluster[0])})

    except Exception as e:
        print("Prediction Error:", str(e))
        return jsonify({"error": str(e)}), 400


# -------------------------------------------------
# 🔹 Endpoint 3: Scan Receipts (OCR Proxy)
# -------------------------------------------------
@app.route("/scan_receipt", methods=["POST"])
def scan_receipt():
    try:
        data = request.get_json()
        
        if not data or "image_base64" not in data:
            return jsonify({"error": "Missing image_base64 field"}), 400
        
        # Forward request to OCR service
        ocr_response = requests.post(
            f"{OCR_SERVICE_URL}/ocr",
            json={"image_base64": data["image_base64"]},
            timeout=30
        )
        
        if ocr_response.status_code == 200:
            return jsonify(ocr_response.json())
        else:
            return jsonify({
                "status": "error",
                "message": f"OCR service error: {ocr_response.status_code}"
            }), 500
        
    except requests.exceptions.Timeout:
        return jsonify({
            "status": "error",
            "message": "OCR service timeout"
        }), 500
    except requests.exceptions.ConnectionError:
        return jsonify({
            "status": "error",
            "message": "OCR service unavailable"
        }), 500
    except Exception as e:
        print("❌ OCR Proxy Error:", str(e))
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 400


# -------------------------------------------------
# Run the server
# -------------------------------------------------
if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)

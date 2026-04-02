from flask import Flask, request, jsonify
import numpy as np
import pandas as pd
import joblib
from flask_cors import CORS

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for frontend communication

# Load trained model
model = joblib.load("random_forest_model.pkl")

# Prediction endpoint
@app.route("/predict_expense", methods=["POST"])
def predict_expense():
    try:
        # Parse input JSON data
        data = request.get_json()
        print("🔹 Received Request: ", data)

        # Map input month data to match trained model's feature names
        input_data = pd.DataFrame([[
            float(data["person"]),
            float(data["month_1"]),  # Map to "2020"
            float(data["month_2"]),  # Map to "2021"
            float(data["month_3"])   # Map to "2022"
        ]], columns=["person", "2020", "2021", "2022"])  # Match trained model feature names

        print("🔹 Transformed Input Data:\n", input_data)

        # Make a prediction
        predicted_value = model.predict(input_data)[0]
        print(f"✅ Prediction: {predicted_value}")

        # Return JSON response
        return jsonify({"predicted_next_month": round(predicted_value, 2)})

    except Exception as e:
        print("❌ Error processing request: ", str(e))
        return jsonify({"error": str(e)}), 400

# Run Flask app
if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)

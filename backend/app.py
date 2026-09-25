from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

feedback_store = []


@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "Flask backend running"})


@app.route("/feedback", methods=["POST"])
def submit_feedback():
    data = request.get_json(silent=True) or request.form

    name = data.get("name")
    message = data.get("message")

    if not name or not message:
        return jsonify({"status": "error", "message": "name and message are required"}), 400

    entry = {"name": name, "message": message}
    feedback_store.append(entry)

    return jsonify({
        "status": "success",
        "entry": entry,
        "totalFeedback": len(feedback_store)
    }), 201


@app.route("/feedback", methods=["GET"])
def list_feedback():
    return jsonify(feedback_store)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

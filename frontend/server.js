const express = require("express");
const axios = require("axios");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

const BACKEND_URL = process.env.BACKEND_URL || "http://localhost:5000";

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.post("/submit", async (req, res) => {
  const { name, message } = req.body;

  try {
    await axios.post(`${BACKEND_URL}/feedback`, { name, message });
    res.redirect("/list");
  } catch (err) {
    res.status(500).send(`
      <h2>Error submitting feedback</h2>
      <p>${err.message}</p>
      <a href="/">Go back</a>
    `);
  }
});

app.get("/list", async (req, res) => {
  try {
    const response = await axios.get(`${BACKEND_URL}/feedback`);
    const entries = response.data;

    const rows = entries.map(e => `
      <tr>
        <td>${e.name}</td>
        <td>${e.message}</td>
      </tr>
    `).join("");

    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Feedback List</title>
        <style>
          body { font-family: sans-serif; max-width: 700px; margin: 60px auto; }
          table { width: 100%; border-collapse: collapse; margin-top: 20px; }
          th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
          nav { margin-bottom: 20px; }
          nav a { margin-right: 15px; }
        </style>
      </head>
      <body>
        <nav>
          <a href="/">Submit Feedback</a>
          <a href="/list">View Feedback</a>
        </nav>
        <h1>Feedback List</h1>
        <table>
          <tr><th>Name</th><th>Message</th></tr>
          ${rows || "<tr><td colspan='2'>No feedback yet</td></tr>"}
        </table>
      </body>
      </html>
    `);
  } catch (err) {
    res.status(500).send(`<h2>Error fetching feedback</h2><p>${err.message}</p>`);
  }
});

app.listen(PORT, () => {
  console.log(`Frontend server running on port ${PORT}`);
  console.log(`Talking to backend at ${BACKEND_URL}`);
});

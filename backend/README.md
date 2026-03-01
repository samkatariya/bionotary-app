# Backend route (add to your existing Node/Express server)

- **`routes/document.js`** — Add the `GET /my-documents` handler to your existing document router, or use this file and ensure `authenticate` and `pool` are provided (e.g. via middleware and your DB module).
- In your main app, mount the document router under `/documents` (e.g. `app.use("/documents", documentRouter)`).
- Restart the server after adding the route.

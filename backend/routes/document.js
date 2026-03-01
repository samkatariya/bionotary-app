const express = require("express");
const router = express.Router();

// Mount with: app.use("/documents", documentRouter);
// Ensure you have: const { authenticate } = require("../middleware/auth");
// and: const pool = require("../db");

router.get("/my-documents", authenticate, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT d.*, n.transaction_hash
       FROM documents d
       LEFT JOIN notarizations n ON n.document_id = d.id
       WHERE d.owner_id = $1
       ORDER BY d.created_at DESC`,
      [req.user.id]
    );

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;

const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const os = require('os');

const app = express();
app.use(cors());              // demo: allow any origin (CloudFront/S3 frontend)
app.use(express.json());

const PORT = process.env.PORT || 3000;

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'bookstore',
  waitForConnections: true,
  connectionLimit: 10
});

// --- health check: this is the path your ALB target group hits ---
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ok', instance: os.hostname() });
  } catch (err) {
    res.status(500).json({ status: 'db unreachable', error: err.message });
  }
});

// Which EC2 instance served this request — useful for demoing load balancing
app.get('/api/whoami', (req, res) => {
  res.json({ instance: os.hostname(), uptime: Math.round(process.uptime()) });
});

// --- books ---
app.get('/api/books', async (req, res) => {
  try {
    const { genre, q } = req.query;
    let sql = 'SELECT * FROM books WHERE 1=1';
    const params = [];
    if (genre) { sql += ' AND genre = ?'; params.push(genre); }
    if (q)     { sql += ' AND (title LIKE ? OR author LIKE ?)'; params.push(`%${q}%`, `%${q}%`); }
    sql += ' ORDER BY id';
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/books/:id', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM books WHERE id = ?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Book not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/books', async (req, res) => {
  try {
    const { title, author, genre, price, stock, description, cover_color } = req.body;
    if (!title || !author || !price) {
      return res.status(400).json({ error: 'Title, author and price are required.' });
    }
    const [result] = await pool.query(
      'INSERT INTO books (title, author, genre, price, stock, description, cover_color) VALUES (?,?,?,?,?,?,?)',
      [title, author, genre || 'General', price, stock || 0, description || '', cover_color || '#3b5b52']
    );
    res.status(201).json({ id: result.insertId, message: 'Book added.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/books/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM books WHERE id = ?', [req.params.id]);
    res.json({ message: 'Book removed.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- orders ---
app.post('/api/orders', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const { book_id, customer, email, quantity } = req.body;
    const qty = parseInt(quantity, 10) || 1;

    await conn.beginTransaction();
    const [rows] = await conn.query('SELECT * FROM books WHERE id = ? FOR UPDATE', [book_id]);
    if (!rows.length) {
      await conn.rollback();
      return res.status(404).json({ error: 'Book not found' });
    }
    const book = rows[0];
    if (book.stock < qty) {
      await conn.rollback();
      return res.status(400).json({ error: `Only ${book.stock} left in stock.` });
    }
    const total = (book.price * qty).toFixed(2);
    await conn.query('UPDATE books SET stock = stock - ? WHERE id = ?', [qty, book_id]);
    const [result] = await conn.query(
      'INSERT INTO orders (book_id, customer, email, quantity, total) VALUES (?,?,?,?,?)',
      [book_id, customer, email, qty, total]
    );
    await conn.commit();
    res.status(201).json({ order_id: result.insertId, total, message: 'Order placed.' });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

app.get('/api/orders', async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT o.id, o.customer, o.email, o.quantity, o.total, o.placed_at, b.title
       FROM orders o JOIN books b ON b.id = o.book_id
       ORDER BY o.placed_at DESC`
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- CPU burner: hit this to trigger the auto scaling policy during your demo ---
app.get('/api/load', (req, res) => {
  const end = Date.now() + 20000;
  while (Date.now() < end) { Math.sqrt(Math.random() * 999999); }
  res.json({ message: 'Burned CPU for 20s', instance: os.hostname() });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Bookstore API listening on ${PORT} — instance ${os.hostname()}`);
});

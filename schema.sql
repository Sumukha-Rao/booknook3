-- Bookstore database: schema + seed data
-- Run once against your RDS MySQL endpoint:
--   mysql -h <RDS-ENDPOINT> -u admin -p < schema.sql

CREATE DATABASE IF NOT EXISTS bookstore;
USE bookstore;

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS books;

CREATE TABLE books (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  title       VARCHAR(200) NOT NULL,
  author      VARCHAR(120) NOT NULL,
  genre       VARCHAR(60)  NOT NULL,
  price       DECIMAL(8,2) NOT NULL,
  stock       INT          NOT NULL DEFAULT 0,
  description TEXT,
  cover_color VARCHAR(7)   DEFAULT '#3b5b52',
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  book_id      INT NOT NULL,
  customer     VARCHAR(120) NOT NULL,
  email        VARCHAR(120) NOT NULL,
  quantity     INT NOT NULL DEFAULT 1,
  total        DECIMAL(8,2) NOT NULL,
  placed_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (book_id) REFERENCES books(id)
);

INSERT INTO books (title, author, genre, price, stock, description, cover_color) VALUES
('The Midnight Library',        'Matt Haig',            'Fiction',     420.00, 14, 'Between life and death there is a library, and its shelves hold infinite versions of the life you could have lived.', '#2f4858'),
('Sapiens',                     'Yuval Noah Harari',    'History',     599.00,  8, 'A sweeping account of how an unremarkable ape came to rule the planet, from cognition to capitalism.',              '#8a5a2b'),
('Atomic Habits',               'James Clear',          'Self-help',   450.00, 27, 'Small changes, compounded daily. A practical framework for building habits that actually stick.',                   '#b5651d'),
('The Silent Patient',          'Alex Michaelides',     'Thriller',    380.00,  0, 'A celebrated painter shoots her husband, then never speaks again. Her therapist is determined to find out why.',    '#3d3a54'),
('Educated',                    'Tara Westover',        'Memoir',      510.00, 11, 'Raised off the grid with no schooling, she taught herself enough to reach Cambridge. A memoir about self-invention.', '#5c6f4a'),
('Project Hail Mary',           'Andy Weir',            'Sci-fi',      560.00, 19, 'A lone astronaut wakes with amnesia on a ship far from Earth, and the survival of humanity depends on him remembering.', '#1f4e5f'),
('The Namesake',                'Jhumpa Lahiri',        'Fiction',     340.00,  6, 'A son of Bengali immigrants in America negotiates the weight of a name he never asked for.',                        '#7a3b3b'),
('Thinking, Fast and Slow',     'Daniel Kahneman',      'Psychology',  649.00,  9, 'The two systems that drive how we think, and the biases that quietly steer nearly every decision we make.',          '#4a4a4a'),
('Wings of Fire',               'A.P.J. Abdul Kalam',   'Biography',   250.00, 32, 'The autobiography of a boy from Rameswaram who became a rocket scientist and then a president.',                    '#a3641c'),
('Norwegian Wood',              'Haruki Murakami',      'Fiction',     399.00,  5, 'A song on a runway pulls a man back to the Tokyo of his twenties, to love, grief, and the friends he lost.',        '#2c5545'),
('Clean Code',                  'Robert C. Martin',     'Technology',  899.00, 12, 'What separates code that works from code that can be read, changed, and trusted a year from now.',                  '#33475b'),
('The Palace of Illusions',     'Chitra B. Divakaruni', 'Mythology',   375.00,  7, 'The Mahabharata retold from Draupadi''s side of the fire, angry, intimate, and unforgiving.',                       '#6b2d3c');

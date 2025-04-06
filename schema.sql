-- Quiz Sets table
CREATE TABLE quiz_sets (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    topic_id INTEGER REFERENCES topics(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Quiz Questions table
CREATE TABLE quiz_questions (
    id SERIAL PRIMARY KEY,
    quiz_set_id INTEGER REFERENCES quiz_sets(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    correct_answer_index INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Quiz Options table
CREATE TABLE quiz_options (
    id SERIAL PRIMARY KEY,
    question_id INTEGER REFERENCES quiz_questions(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL,
    option_index INTEGER NOT NULL
);

-- Quiz Results table
CREATE TABLE quiz_results (
    id SERIAL PRIMARY KEY,
    quiz_set_id INTEGER REFERENCES quiz_sets(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL, -- Using TEXT for Supabase Auth user_id is simpler
    score INTEGER NOT NULL,
    total_questions INTEGER NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Flashcard Decks table
CREATE TABLE flashcard_decks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    topic_id INTEGER REFERENCES topics(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Flashcards table
CREATE TABLE flashcards (
    id SERIAL PRIMARY KEY,
    deck_id INTEGER REFERENCES flashcard_decks(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Flashcard Progress table
CREATE TABLE flashcard_progress (
    id SERIAL PRIMARY KEY,
    flashcard_id INTEGER REFERENCES flashcards(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL, -- Using TEXT for Supabase Auth user_id is simpler
    is_known BOOLEAN DEFAULT false,
    last_reviewed TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create updated_at trigger function (only needed once)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply update trigger only to tables with updated_at column
CREATE TRIGGER update_quiz_sets_updated_at
    BEFORE UPDATE ON quiz_sets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_flashcard_decks_updated_at
    BEFORE UPDATE ON flashcard_decks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add sample data for testing
INSERT INTO quiz_sets (title, description) VALUES
('Basic Science Quiz', 'Test your knowledge of basic science concepts'),
('History 101', 'Basic history questions');

WITH quiz AS (SELECT id FROM quiz_sets WHERE title = 'Basic Science Quiz' LIMIT 1)
INSERT INTO quiz_questions (quiz_set_id, question, correct_answer_index)
SELECT quiz.id, 'What is the chemical symbol for gold?', 2
FROM quiz;

WITH question AS (
    SELECT id FROM quiz_questions 
    WHERE question = 'What is the chemical symbol for gold?' LIMIT 1
)
INSERT INTO quiz_options (question_id, option_text, option_index)
SELECT question.id, option_text, option_index
FROM question, unnest(ARRAY['Ag', 'Au', 'Fe', 'Cu']) WITH ORDINALITY AS t(option_text, option_index);

INSERT INTO flashcard_decks (title, description) VALUES
('Chemistry Basics', 'Basic chemistry concepts and definitions');

WITH deck AS (SELECT id FROM flashcard_decks WHERE title = 'Chemistry Basics' LIMIT 1)
INSERT INTO flashcards (deck_id, question, answer)
SELECT deck.id, 'What is an atom?', 'The basic unit of matter that consists of a nucleus surrounded by electrons'
FROM deck; 
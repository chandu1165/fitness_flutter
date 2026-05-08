import sqlite3
import secrets
import hashlib
import re
from datetime import date, datetime, timedelta, timezone
from functools import wraps

from flask import Flask, g, jsonify, request
from flask_cors import CORS
from werkzeug.security import check_password_hash, generate_password_hash

app = Flask(__name__)
CORS(app)

DATABASE = 'fitness.db'
SESSION_DURATION_DAYS = 7
EMAIL_PATTERN = re.compile(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')

BODY_TYPE_PLANS = {
    'leaning': {
        'title': 'Leaning Plan',
        'focus': 'Fat loss with endurance and light-to-moderate strength work',
        'rep_range': '12 to 20 reps',
        'exercises': [
            'Running',
            'Cycling',
            'Skipping',
            'Light weight training',
            'Moderate weight training'
        ]
    },
    'bulking': {
        'title': 'Bulking Plan',
        'focus': 'Muscle gain with compound strength training',
        'rep_range': '12 to 20 reps',
        'exercises': [
            'Squats',
            'Deadlifts',
            'Bench Press',
            'Overhead Press'
        ]
    },
    'weightloss': {
        'title': 'Weight Loss Plan',
        'focus': 'High calorie burn with cardio and full-body movement',
        'rep_range': '15 to 20 reps',
        'exercises': [
            'Brisk walking',
            'Jogging',
            'Cycling',
            'Jump rope',
            'Bodyweight squats',
            'Mountain climbers'
        ]
    },
    'cutting': {
        'title': 'Cutting Plan',
        'focus': 'Muscle definition with moderate weights and isolation work',
        'rep_range': '10 to 15 reps',
        'exercises': [
            'Abs exercises',
            'Shoulder isolation exercises',
            'Arm isolation exercises',
            'Moderate weight training'
        ]
    }
}

SYSTEM_DAILY_CHALLENGE = {
    'title': 'System Daily Workout',
    'theme': 'Solo Leveling inspired challenge board',
    'tasks': [
        {'name': 'Push-ups', 'target': '100 reps'},
        {'name': 'Sit-ups', 'target': '100 reps'},
        {'name': 'Squats', 'target': '100 reps'},
        {'name': 'Run', 'target': '10 km'}
    ],
    'message': 'Complete the daily quest to level up your consistency.'
}

VALID_TASK_NAMES = {task['name'] for task in SYSTEM_DAILY_CHALLENGE['tasks']}


def get_db():
    if 'db' not in g:
        g.db = sqlite3.connect(DATABASE)
        g.db.row_factory = sqlite3.Row
    return g.db


def init_db():
    db = sqlite3.connect(DATABASE)
    db.execute(
        '''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL
        )
        '''
    )
    db.execute(
        '''
        CREATE TABLE IF NOT EXISTS user_profiles (
            user_id INTEGER PRIMARY KEY,
            height_cm REAL,
            weight_kg REAL,
            body_goal TEXT,
            last_bmi REAL,
            bmi_category TEXT,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
        '''
    )
    db.execute(
        '''
        CREATE TABLE IF NOT EXISTS workout_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            progress_date TEXT NOT NULL,
            task_name TEXT NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0,
            UNIQUE(user_id, progress_date, task_name),
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
        '''
    )
    db.execute(
        '''
        CREATE TABLE IF NOT EXISTS auth_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            token_hash TEXT UNIQUE NOT NULL,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            revoked_at TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
        '''
    )
    db.commit()
    db.close()


def ensure_test_user():
    email = 'test@gmail.com'
    password_hash = generate_password_hash('1234')
    db = sqlite3.connect(DATABASE)

    existing_user = db.execute(
        'SELECT id FROM users WHERE email = ?',
        (email,)
    ).fetchone()

    if existing_user:
        db.execute(
            'UPDATE users SET password_hash = ? WHERE email = ?',
            (password_hash, email)
        )
    else:
        db.execute(
            'INSERT INTO users (email, password_hash) VALUES (?, ?)',
            (email, password_hash)
        )

    db.commit()
    db.close()


@app.teardown_appcontext
def close_db(error):
    db = g.pop('db', None)
    if db is not None:
        db.close()


def json_error(message, status_code):
    return jsonify({'success': False, 'message': message}), status_code


def get_json_data():
    data = request.get_json(silent=True)
    if data is None or not isinstance(data, dict):
        return None, json_error('Request body must be valid JSON', 400)
    return data, None


def validate_login_credentials(data):
    email = str(data.get('email', '')).strip().lower()
    password = str(data.get('password', ''))

    if not email or not password:
        return None, None, json_error('Email and password are required', 400)

    if not EMAIL_PATTERN.match(email):
        return None, None, json_error('Enter a valid email address', 400)

    return email, password, None


def validate_signup_credentials(data):
    email, password, login_error = validate_login_credentials(data)
    if login_error:
        return None, None, login_error

    if len(password) < 8:
        return None, None, json_error('Password must be at least 8 characters', 400)

    if not any(character.isalpha() for character in password):
        return None, None, json_error('Password must include at least one letter', 400)

    if not any(character.isdigit() for character in password):
        return None, None, json_error('Password must include at least one number', 400)

    return email, password, None


def hash_token(token):
    return hashlib.sha256(token.encode('utf-8')).hexdigest()


def utc_now():
    return datetime.now(timezone.utc)


def create_session(user_id):
    token = secrets.token_urlsafe(32)
    token_hash = hash_token(token)
    created_at = utc_now()
    expires_at = created_at + timedelta(days=SESSION_DURATION_DAYS)
    db = get_db()
    db.execute(
        '''
        INSERT INTO auth_sessions (user_id, token_hash, created_at, expires_at, revoked_at)
        VALUES (?, ?, ?, ?, NULL)
        ''',
        (user_id, token_hash, created_at.isoformat(), expires_at.isoformat())
    )
    db.commit()
    return token, expires_at


def revoke_session(token):
    db = get_db()
    db.execute(
        '''
        UPDATE auth_sessions
        SET revoked_at = ?
        WHERE token_hash = ? AND revoked_at IS NULL
        ''',
        (utc_now().isoformat(), hash_token(token))
    )
    db.commit()


def revoke_sessions_for_user(user_id):
    db = get_db()
    db.execute(
        '''
        UPDATE auth_sessions
        SET revoked_at = ?
        WHERE user_id = ? AND revoked_at IS NULL
        ''',
        (utc_now().isoformat(), user_id)
    )
    db.commit()


def get_session_for_token(token):
    db = get_db()
    session = db.execute(
        '''
        SELECT auth_sessions.id, auth_sessions.user_id, auth_sessions.expires_at,
               auth_sessions.revoked_at, users.email
        FROM auth_sessions
        JOIN users ON users.id = auth_sessions.user_id
        WHERE auth_sessions.token_hash = ?
        ''',
        (hash_token(token),)
    ).fetchone()

    if not session:
        return None

    if session['revoked_at']:
        return None

    expires_at = datetime.fromisoformat(session['expires_at'])
    if expires_at <= utc_now():
        db.execute(
            'UPDATE auth_sessions SET revoked_at = ? WHERE id = ?',
            (utc_now().isoformat(), session['id'])
        )
        db.commit()
        return None

    return session


def calculate_bmi(weight_kg, height_cm):
    height_m = height_cm / 100
    return weight_kg / (height_m * height_m)


def bmi_category_for(bmi_value):
    if bmi_value < 18.5:
        return 'Underweight'
    if bmi_value < 25:
        return 'Normal'
    if bmi_value < 30:
        return 'Overweight'
    return 'Obese'


def get_user_by_email(email):
    db = get_db()
    return db.execute(
        'SELECT id, email FROM users WHERE email = ?',
        (email,)
    ).fetchone()


def calculate_goal_targets(weight_kg, body_goal):
    if not weight_kg or not body_goal:
        return None

    maintenance = round(weight_kg * 33)
    adjustments = {
        'leaning': -250,
        'bulking': 300,
        'weightloss': -500,
        'cutting': -350
    }
    calorie_target = maintenance + adjustments.get(body_goal, 0)

    return {
        'maintenance_calories': maintenance,
        'goal_calories': calorie_target,
        'protein_grams': round(weight_kg * 2.0),
        'carbs_grams': round(weight_kg * 3.0 if body_goal == 'bulking' else weight_kg * 2.2),
        'fats_grams': round(weight_kg * 0.8),
        'goal': body_goal
    }


def serialize_profile(profile_row):
    if not profile_row:
        return {
            'height_cm': None,
            'weight_kg': None,
            'body_goal': None,
            'last_bmi': None,
            'bmi_category': None
        }

    weight_kg = profile_row['weight_kg']
    body_goal = profile_row['body_goal']
    return {
        'height_cm': profile_row['height_cm'],
        'weight_kg': weight_kg,
        'body_goal': body_goal,
        'last_bmi': profile_row['last_bmi'],
        'bmi_category': profile_row['bmi_category'],
        'calorie_targets': calculate_goal_targets(weight_kg, body_goal)
    }


def get_profile_for_user(user_id):
    db = get_db()
    return db.execute(
        '''
        SELECT height_cm, weight_kg, body_goal, last_bmi, bmi_category
        FROM user_profiles
        WHERE user_id = ?
        ''',
        (user_id,)
    ).fetchone()


def get_daily_progress_for_user(user_id):
    db = get_db()
    progress_date = date.today().isoformat()
    rows = db.execute(
        '''
        SELECT task_name, completed
        FROM workout_progress
        WHERE user_id = ? AND progress_date = ?
        ''',
        (user_id, progress_date)
    ).fetchall()

    progress_map = {row['task_name']: bool(row['completed']) for row in rows}
    tasks = [
        {
            'name': task['name'],
            'target': task['target'],
            'completed': progress_map.get(task['name'], False)
        }
        for task in SYSTEM_DAILY_CHALLENGE['tasks']
    ]
    completed_count = sum(1 for task in tasks if task['completed'])

    return {
        'date': progress_date,
        'tasks': tasks,
        'completed_count': completed_count,
        'total_count': len(tasks)
    }


def get_history_summary_for_user(user_id, days=30):
    db = get_db()
    end_date = date.today()
    start_date = end_date - timedelta(days=days - 1)
    rows = db.execute(
        '''
        SELECT progress_date
        FROM workout_progress
        WHERE user_id = ? AND completed = 1 AND progress_date BETWEEN ? AND ?
        GROUP BY progress_date
        ORDER BY progress_date ASC
        ''',
        (user_id, start_date.isoformat(), end_date.isoformat())
    ).fetchall()

    completed_dates = {row['progress_date'] for row in rows}
    calendar_days = []
    for offset in range(days):
        current_day = start_date + timedelta(days=offset)
        iso_date = current_day.isoformat()
        calendar_days.append({
            'date': iso_date,
            'day': current_day.day,
            'weekday': current_day.strftime('%a'),
            'completed': iso_date in completed_dates,
            'is_today': current_day == end_date
        })

    current_streak = 0
    cursor = end_date
    while cursor.isoformat() in completed_dates:
        current_streak += 1
        cursor -= timedelta(days=1)

    best_streak = 0
    streak = 0
    cursor = start_date
    while cursor <= end_date:
        if cursor.isoformat() in completed_dates:
            streak += 1
            best_streak = max(best_streak, streak)
        else:
            streak = 0
        cursor += timedelta(days=1)

    return {
        'calendar_days': calendar_days,
        'completed_days': len(completed_dates),
        'current_streak': current_streak,
        'best_streak': best_streak,
        'weekly_goal': 3
    }


def token_required(route_handler):
    @wraps(route_handler)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return json_error('Authorization token is required', 401)

        token = auth_header.split(' ', 1)[1].strip()
        if not token:
            return json_error('Authorization token is required', 401)

        session = get_session_for_token(token)
        if not session:
            return json_error('Invalid or expired token', 401)

        request.auth_token = token
        request.user_email = session['email']
        request.user = {'id': session['user_id'], 'email': session['email']}
        return route_handler(*args, **kwargs)

    return wrapper

@app.route('/signup', methods=['POST'])
def signup():
    data, error_response = get_json_data()
    if error_response:
        return error_response

    email, password, validation_error = validate_signup_credentials(data)
    if validation_error:
        return validation_error

    password_hash = generate_password_hash(password)
    db = get_db()

    existing_user = db.execute(
        'SELECT id FROM users WHERE email = ?',
        (email,)
    ).fetchone()

    if existing_user:
        return json_error('User already exists', 400)

    db.execute(
        'INSERT INTO users (email, password_hash) VALUES (?, ?)',
        (email, password_hash)
    )
    db.commit()

    return jsonify({
        'success': True,
        'message': 'Signup successful',
        'user': {'email': email}
    }), 201


@app.route('/login', methods=['POST'])
def login():
    data, error_response = get_json_data()
    if error_response:
        return error_response

    email, password, validation_error = validate_login_credentials(data)
    if validation_error:
        return validation_error

    db = get_db()
    user = db.execute(
        'SELECT id, email, password_hash FROM users WHERE email = ?',
        (email,)
    ).fetchone()

    if not user or not check_password_hash(user['password_hash'], password):
        return json_error('Invalid credentials', 401)

    token, expires_at = create_session(user['id'])

    return jsonify({
        'success': True,
        'message': 'Login successful',
        'token': token,
        'expires_at': expires_at.isoformat(),
        'user': {'email': user['email']}
    }), 200


@app.route('/forgot-password', methods=['POST'])
def forgot_password():
    data, error_response = get_json_data()
    if error_response:
        return error_response

    email = str(data.get('email', '')).strip().lower()
    new_password = str(data.get('new_password', ''))

    if not email or not new_password:
        return json_error('Email and new password are required', 400)

    email, new_password, validation_error = validate_signup_credentials({
        'email': email,
        'password': new_password
    })
    if validation_error:
        return validation_error

    db = get_db()
    user = db.execute(
        'SELECT id, email FROM users WHERE email = ?',
        (email,)
    ).fetchone()

    if not user:
        return json_error('No account found for that email', 404)

    db.execute(
        'UPDATE users SET password_hash = ? WHERE id = ?',
        (generate_password_hash(new_password), user['id'])
    )
    db.commit()
    revoke_sessions_for_user(user['id'])

    return jsonify({
        'success': True,
        'message': 'Password reset successful. Please log in again.'
    }), 200


@app.route('/profile', methods=['GET'])
@token_required
def profile():
    profile_row = get_profile_for_user(request.user['id'])
    return jsonify({
        'success': True,
        'message': 'Profile fetched successfully',
        'user': {'email': request.user_email},
        'profile': serialize_profile(profile_row)
    }), 200


@app.route('/profile/update', methods=['POST'])
@token_required
def update_profile():
    data, error_response = get_json_data()
    if error_response:
        return error_response

    try:
        height_cm = float(data.get('height_cm', 0))
        weight_kg = float(data.get('weight_kg', 0))
    except (TypeError, ValueError):
        return json_error('Height and weight must be numbers', 400)

    body_goal = str(data.get('body_goal', '')).strip().lower()

    if height_cm <= 0 or weight_kg <= 0:
        return json_error('Height and weight must be greater than zero', 400)

    if body_goal not in BODY_TYPE_PLANS:
        return json_error('Select a valid body goal', 400)

    bmi_value = round(calculate_bmi(weight_kg, height_cm), 2)
    bmi_category = bmi_category_for(bmi_value)
    db = get_db()

    db.execute(
        '''
        INSERT INTO user_profiles (
            user_id, height_cm, weight_kg, body_goal, last_bmi, bmi_category, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(user_id) DO UPDATE SET
            height_cm = excluded.height_cm,
            weight_kg = excluded.weight_kg,
            body_goal = excluded.body_goal,
            last_bmi = excluded.last_bmi,
            bmi_category = excluded.bmi_category,
            updated_at = CURRENT_TIMESTAMP
        ''',
        (request.user['id'], height_cm, weight_kg, body_goal, bmi_value, bmi_category)
    )
    db.commit()

    profile_row = get_profile_for_user(request.user['id'])
    return jsonify({
        'success': True,
        'message': 'Profile updated successfully',
        'profile': serialize_profile(profile_row)
    }), 200


@app.route('/logout', methods=['POST'])
@token_required
def logout():
    revoke_session(request.auth_token)

    return jsonify({
        'success': True,
        'message': 'Logout successful'
    }), 200


@app.route('/body-types', methods=['GET'])
def body_types():
    return jsonify({
        'success': True,
        'body_types': [
            {'key': key, 'title': plan['title'], 'focus': plan['focus']}
            for key, plan in BODY_TYPE_PLANS.items()
        ]
    }), 200


@app.route('/workout', methods=['GET'])
def workout():
    body_type = request.args.get('body_type', '').strip().lower()

    if not body_type:
        return jsonify({
            'success': False,
            'message': 'Select a body type to get a workout plan',
            'available_body_types': list(BODY_TYPE_PLANS.keys())
        }), 200

    if body_type not in BODY_TYPE_PLANS:
        return jsonify({
            'success': False,
            'message': 'Invalid body type selected',
            'available_body_types': list(BODY_TYPE_PLANS.keys())
        }), 400

    return jsonify({
        'success': True,
        'selected_body_type': body_type,
        'plan': BODY_TYPE_PLANS[body_type]
    }), 200


@app.route('/daily-workout', methods=['GET'])
def daily_workout():
    return jsonify({
        'success': True,
        'daily_workout': SYSTEM_DAILY_CHALLENGE
    }), 200


@app.route('/daily-workout/progress', methods=['GET'])
@token_required
def daily_workout_progress():
    progress = get_daily_progress_for_user(request.user['id'])
    return jsonify({
        'success': True,
        'progress': progress
    }), 200


@app.route('/daily-workout/progress', methods=['POST'])
@token_required
def update_daily_workout_progress():
    data, error_response = get_json_data()
    if error_response:
        return error_response

    task_name = str(data.get('task_name', '')).strip()
    completed = bool(data.get('completed', False))

    if task_name not in VALID_TASK_NAMES:
        return json_error('Invalid task name', 400)

    progress_date = date.today().isoformat()
    db = get_db()
    db.execute(
        '''
        INSERT INTO workout_progress (user_id, progress_date, task_name, completed)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(user_id, progress_date, task_name) DO UPDATE SET
            completed = excluded.completed
        ''',
        (request.user['id'], progress_date, task_name, int(completed))
    )
    db.commit()

    progress = get_daily_progress_for_user(request.user['id'])
    return jsonify({
        'success': True,
        'message': 'Daily progress updated successfully',
        'progress': progress
    }), 200


@app.route('/dashboard', methods=['GET'])
@token_required
def dashboard():
    profile_row = get_profile_for_user(request.user['id'])
    progress = get_daily_progress_for_user(request.user['id'])
    history_summary = get_history_summary_for_user(request.user['id'])
    return jsonify({
        'success': True,
        'user': {'email': request.user_email},
        'profile': serialize_profile(profile_row),
        'daily_workout': {
            'title': SYSTEM_DAILY_CHALLENGE['title'],
            'theme': SYSTEM_DAILY_CHALLENGE['theme'],
            'message': SYSTEM_DAILY_CHALLENGE['message']
        },
        'daily_progress': progress,
        'history_summary': history_summary
    }), 200


@app.route('/calories', methods=['POST'])
def calories():
    data, error_response = get_json_data()
    if error_response:
        return error_response

    try:
        weight = float(data.get('weight', 0))
        duration = float(data.get('duration', 0))
    except (TypeError, ValueError):
        return json_error('Weight and duration must be numbers', 400)

    if weight <= 0 or duration <= 0:
        return json_error('Weight and duration must be greater than zero', 400)

    return jsonify({
        'success': True,
        'calories': round(weight * duration * 0.03, 2)
    }), 200


@app.route('/create', methods=['GET'])
def create_user():
    return json_error('Test user seed route is disabled for real authentication flows', 403)


@app.route('/dev/seed-test-user', methods=['POST'])
def seed_test_user():
    email = 'test@gmail.com'
    test_password = '1234'
    password_hash = generate_password_hash(test_password)
    db = get_db()

    existing_user = db.execute(
        'SELECT id FROM users WHERE email = ?',
        (email,)
    ).fetchone()

    if existing_user:
        db.execute(
            'UPDATE users SET password_hash = ? WHERE email = ?',
            (password_hash, email)
        )
        db.commit()
        return jsonify({
            'success': True,
            'message': 'Test user password reset successfully',
            'user': {'email': email, 'password_hint': test_password}
        }), 200

    db.execute(
        'INSERT INTO users (email, password_hash) VALUES (?, ?)',
        (email, password_hash)
    )
    db.commit()

    return jsonify({
        'success': True,
        'message': 'Test user created',
        'user': {'email': email, 'password_hint': test_password}
    }), 201


init_db()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

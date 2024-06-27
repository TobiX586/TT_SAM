from flask import Flask, request, jsonify, render_template
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import datetime

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///sam.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
CORS(app)

class Program(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    description = db.Column(db.String(200), nullable=True)

class Usage(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(80), nullable=False)
    software_id = db.Column(db.String(80), nullable=False)
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime, nullable=False)
    duration = db.Column(db.Float, nullable=False)

@app.route('/api/programs', methods=['GET', 'POST', 'DELETE'])
def programs():
    if request.method == 'POST':
        data = request.get_json()
        new_program = Program(name=data['name'], description=data.get('description', ''))
        db.session.add(new_program)
        db.session.commit()
        return jsonify({"message": "Program added successfully"}), 201
    elif request.method == 'DELETE':
        data = request.get_json()
        program = Program.query.filter_by(name=data['name']).first()
        if program:
            db.session.delete(program)
            db.session.commit()
            return jsonify({"message": "Program deleted successfully"}), 200
        return jsonify({"message": "Program not found"}), 404
    else:
        programs = Program.query.all()
        return jsonify({"programs": [{"name": program.name, "description": program.description} for program in programs]})

@app.route('/api/usage', methods=['POST', 'GET'])
def add_usage():
    if request.method == 'POST':
        data = request.get_json()
        new_usage = Usage(
            user_id=data['user_id'],
            software_id=data['software_id'],
            start_time=datetime.datetime.fromisoformat(data['start_time']),
            end_time=datetime.datetime.fromisoformat(data['end_time']),
            duration=data['duration']
        )
        db.session.add(new_usage)
        db.session.commit()
        return jsonify({"message": "Usage data added successfully"}), 201
    else:
        usages = Usage.query.all()
        return jsonify({"usages": [
            {
                "id": usage.id,
                "user_id": usage.user_id,
                "software_id": usage.software_id,
                "start_time": usage.start_time.isoformat(),
                "end_time": usage.end_time.isoformat(),
                "duration": usage.duration
            } for usage in usages
        ]})

@app.route('/')
def index():
    programs = Program.query.all()
    usages = Usage.query.all()
    return render_template('index.html', programs=programs, usages=usages)

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True)

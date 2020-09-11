from flask import Flask
app = Flask(__name__)


@app.route("/")
def index():
    return "Index! Hier wat html teruggeven."


@app.route("/start/")
def hello():
    # Write vort-met-de-geit.txt
    return "Succesmelding"


if __name__ == "__main__":
    # Starts on port 5000 by default.
    app.run()

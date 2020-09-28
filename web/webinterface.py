import os.path
from flask import Flask, request
app = Flask(__name__)


@app.route("/", methods=['GET', 'POST'])
def index():
    if os.path.isfile("/code/datachecker/datachecker_running.txt"):
        datachecker_status = "running"
    else:
        datachecker_status = "not running"
    
    if os.path.isfile("/code/modelbuilder/modelbuilder_running.txt"):
        modelbuilder_status = "running"
    else:
        modelbuilder_status = "not running"
    
    if datachecker_status == 'running' or modelbuilder_status == 'running':
        form_disabled = 'disabled'
    else:
        form_disabled = ''
    
    return """
    <head>
        <title>Datachecker/Modelbuilder</title>
    </head>
    <h2>Datachecker</h2>
    Status: {}<br><br>
        <form action = "/datachecker/start/" method = "get">
            <input type = "submit" value = "Start Datachecker" {}/></p>
        </form><br>
        
    <h2>Modelbuilder</h2>
    Status: {}<br><br>
    
        <form action = "/modelbuilder/start/" method = "post">
            polder id: <input type = "number" name = "polder_id" value = "id"/></p>
            naam: <input type = "text" name = "polder_name" value = ""/></p>
            <input type = "submit" value = "Start modelbuilder" {} /></p>
        </form>
    """.format(datachecker_status,form_disabled,modelbuilder_status,form_disabled)


@app.route("/datachecker/start/", methods=['GET', 'POST'])
def datachecker_start():
    with open('/code/datachecker/datachecker_running.txt', 'w') as fp: 
        pass
    os.system("python3 /code/datachecker/datachecker.py &")
    return """<head>
        <meta http-equiv='refresh' content='5; URL=/'>
        </head>
        Datachecker gestart, je wordt terugverwezen naar de vorige pagina binnen enkele seconde"""
    
@app.route("/modelbuilder/start/", methods=['GET', 'POST'])
def modelbuilder_start():
    polder_id = request.form['polder_id']
    polder_name = request.form['polder_name']
    
    if polder_id == '' or polder_name == '':
        return 'Fill in both a polder id and name'
    
    with open('/code/modelbuilder/modelbuilder_running.txt', 'w') as fp: 
        pass
    os.system("python3 /code/modelbuilder/modelbuilder.py {} {} &".format(polder_id,polder_name))
    return """<head>
            <meta http-equiv='refresh' content='5; URL=/'>
            </head>
        Modelbuilder gestart, je wordt terugverwezen naar de vorige pagina binnen enkele seconde"""
        
if __name__ == "__main__":
    # Starts on port 5000 by default.
    app.run(debug=True,host='0.0.0.0')

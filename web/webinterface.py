import os.path
from time import sleep

from flask import Flask, request

app = Flask(__name__)
import subprocess
import sys
from pathlib import Path

# set the work-dir so code-dir can be found
if not Path("code").absolute().resolve().exists():
    os.chdir(Path(__file__).absolute().resolve().parents[2])

work_dir = Path.cwd()


def datachecker_running():
    return work_dir.joinpath("code/datachecker/datachecker_running.txt").is_file()


def modelbuilder_running():
    return work_dir.joinpath(r"code/modelbuilder/modelbuilder_running.txt").is_file()


def get_status():
    return {
        "datachecker": not datachecker_running(),
        "modelbuilder": not modelbuilder_running(),
    }


@app.route("/", methods=["GET", "POST"])
def index():
    if work_dir.joinpath("code/datachecker/datachecker_running.txt").is_file():
        datachecker_status = "running"
    else:
        datachecker_status = "not running"

    if work_dir.joinpath(r"code/modelbuilder/modelbuilder_running.txt").is_file():
        modelbuilder_status = "running"
    else:
        modelbuilder_status = "not running"

    if datachecker_status == "running" or modelbuilder_status == "running":
        refresh = """<meta http-equiv="refresh" content="10" />"""
        form_disabled = "disabled"
    else:
        refresh = ""
        form_disabled = ""

    return """
    <head>
        <title>Datachecker/Modelbuilder</title>
        {}
    </head>
    <h2>Datachecker</h2>
    Status: {}<br>
        <a href="/datachecker/log" target="_blank">View logfile</a><br><br>
        <form action = "/datachecker/start/" method = "get">
            <input type = "submit" value = "Start Datachecker" {}/></p>
        </form><br>
        
    <h2>Modelbuilder</h2>
    Status: {}<br>
        <a href="/modelbuilder/log" target="_blank">View logfile</a><br><br>
    
        <form action = "/modelbuilder/start/" method = "post">
            polder id: <input type = "number" name = "polder_id" value = "id" {} /></p>
            naam: <input type = "text" name = "polder_name" value = "" {} /></p>
            <input type = "submit" value = "Start modelbuilder" {} /></p>
        </form>
    <br>    
    <h2>Instructies</h2>
        <ul>
            <li>Maak een FME export van de gewenste gebieden. Zie de lijst hieronder.</li>
            <li>Zet de invoerdata (DAMO.gdb en HDB.gdb) klaar in de invoermap (data/input).</li>
            <li>Klik op "Start Datachecker"</li>
            <li>Zolang de Datachecker draait kan je de Modelbuilder nog niet gebruiken. Ververs de pagina om te zien of de datachecker klaar is.</li>
            <li>Zodra de Datachecker klaar is wordt de output weggeschereven naar de uitvoermap (data/output).</li>
            <li>Voer na het draaien van de datachecker de polder id en poldernaam in. De id verwijst naar de polder_id in de laag polderclusters in de HDB. Zie voor de standaard lijst hieronder. Deze polder wordt uit de datachecker data geknipt en gebruikt om het model op te bouwen. De gegevens voor het model moeten dus in de datachecker zitten! De poldernaam wordt gebruikt voor oa naamgeving van bestanden.</li>
            <li>Zodra de Modelbuilder klaar is (ververs de pagina voor een statusupdate) wordt het model en feedback weggeschreven naar de uitvoermap (data/output).</li>
            <li>Zolang de datachecker draait staat er een bestand 'datachecker_running.txt' in de datachecker map. Mocht de datachecker veel langer dan normaal draaien kan het zijn dat hij ergens in het proces vast is gelopen. Het verwijderen van dit bestand geeft de datachecker weer vrij. Voor de modelbuilder is er eenzelfde bestand in de modelbuilder map.</li>
            <li>De logging is in te zien door bovenstaand op 'view logfile' te klikken. Hier kan je onder andere zien waar in het proces de datachecker is. In de datachecker en modelbuilder mappen staan tevens de logbestanden.</li>
        </ul>  
    <h2>Overzicht gebieden</h2>
        <pre>
            ID	Naam				Code Polders V4
            1	Heerhugowaard			"03150","03350"
            2	Drieban				"6090"
            3	Purmer				"5801","5802","5803"
            4	Grootlimmerpolder		"04230","04290","04300"
            5	Koegras				"2060","2040","2010","20601"
            6	Marken				"5160"
            7	HUB				"04310","04320","04541","04542"
            8	Beemster			"5400","5401"
            9	VNK				"6750"
            10	t Hoekje			"2020","2040"
            11	Assendelft			"04751","04752","04380"
            12	Grootslag			"6700","6770","6780","6080"
            13	Heiloo				"04170","04650","04160","04200"
            14	Purmerend			"5741","5742","5721","5722","5841","5842","5320"
            15	Starnmeer			"04460"
            16	Eijerland			8040,"8071"
            17	Mijzen				"04520"
            18	Oudorp				"03765"
            20	Wijdewormer			"5310"
            21	Noorderkaag			"03703"
            23	Edam Volendam Katwoude		"5360","5781","5761","5762","5782"
            24	VRNK-Oost			"2100","2110","03190","03200","03210","6753"
            25	Wieringermeer			"7701","7702","7703","7704"
            26	Binnenduinrand Egmond		"04100","04150","04902","04220","04902-00"
            27	Geestmerambacht			"03764","03751","03240","03801","03802","03763","03300","03752"
            28	Waterland			"5170","5470","5821","5480","5230","5240","5560","5220","5180","5410","5250","5440","5500","5150","5510","5260","5520","5822","5200","5490","5210","5530","5540","5550","5570","5460","5600","5610","5620","5580","5390","5171"
            29	Schermer			"04851","04852","04853"
            30	Zijpe-West			"2751","2752","2775","2754","2780","2779","2050","2756"
            31	Oosterpolder Hoorn		"6110","6100"
            32	Westzaan			"04400","04390"
            33	Bergermeer			"04070","04080","04090","04952","04953","04640"
            34	Wieringerwaard			"2080"
            35	Schagerkogge			"03010","03020","03030","03040","03050","03060","03701","03702"
            36	Zeevang				"5701","5702","5703","5704","5705"
            37	Westerkogge			"6130"
            38	Alkmaardermeerpolders		"04250","04280","04260","04420","04270", "04240"
            39	Wieringen			"2851","2852","2854","2855","2856"
            40	Zijpe-Zuid			"2757","2758","2759","2781","2763","2764","2765","2766"
            41	Egmondermeer			"04130","04110","04951"
            42	Oostzaan			"5330","5340"
            43	HOUW (Wohoobur)			"6180","6190","6200","6210"
            44	Zijpe-Noord			"2767","2768","2772","2769","2773","2774","2120"
            45	Callantsoog			"2030","2040"
            46	Bergen-Noord			"04010","04020","04030","04040","04050","04060"
            47	Berkmeer e.o.			"6230","6240","03130","03140"
            48	Valkkoog en Schagerwaard	"03080","03090"
            49	Waar Woud Spek eet		"03100","03110","03120","03340"
            50	Wormer				"5270","5280","5290","5300"
            51	Eilandspolder			"04801","04802","04803","04804","04470"
            53	VRNK-West			"03160","03170","03180","03070"
            54	Anna Paulowna			"2803","2804","2805"
            55	NZK-polders			"04340","04580","04590","04610","04410"
            56	Beetskoog			"5010","5020","5030","5040","5050","5080"
            57	Texel-Zuid			"8010","8020","8030","8071"
        <pre>
    """.format(
        refresh,
        datachecker_status,
        form_disabled,
        modelbuilder_status,
        form_disabled,
        form_disabled,
        form_disabled,
    )


# %%


@app.route("/datachecker/start/", methods=["GET", "POST"])
def datachecker_start():
    with open(work_dir.joinpath("code/datachecker/datachecker_running.txt"), "w") as fp:
        pass
    subprocess.Popen([f"{sys.executable}", "code/datachecker/datachecker.py"])
    return """<head>
        <meta http-equiv='refresh' content='5; URL=/'>
        </head>
        Datachecker gestart, je wordt terugverwezen naar de vorige pagina binnen enkele seconde"""


@app.route("/modelbuilder/start/", methods=["GET", "POST"])
def modelbuilder_start():
    polder_id = request.form["polder_id"]
    polder_name = request.form["polder_name"]

    if polder_id == "" or polder_name == "":
        return "Fill in both a polder id and name"

    with open(
        work_dir.joinpath("code/modelbuilder/modelbuilder_running.txt"), "w"
    ) as fp:
        pass
    subprocess.Popen(
        [
            f"{sys.executable}",
            "code/modelbuilder/modelbuilder.py",
            str(polder_id),
            str(polder_name),
        ]
    )
    return """<head>
            <meta http-equiv='refresh' content='5; URL=/'>
            </head>
        Modelbuilder gestart, je wordt terugverwezen naar de vorige pagina binnen enkele seconde"""


@app.route("/datachecker/log")
def stream_datachecker():
    def generate():
        with open(work_dir.joinpath("code/datachecker/datachecker.log")) as f:
            yield f.read()

    return app.response_class(generate(), mimetype="text/plain")


@app.route("/modelbuilder/log")
def stream_modelbuilder():
    def generate():
        with open(work_dir.joinpath("code/modelbuilder/modelbuilder.log")) as f:
            yield f.read()

    return app.response_class(generate(), mimetype="text/plain")


@app.route("/status")
def status():
    return get_status()


if __name__ == "__main__":
    # Starts on port 5000 by default.
    app.run(debug=True, host="0.0.0.0")

# hhnk-modelbuilder

This modelbuilder convert a DAMO export from Hoogheemraadschap Hollands Noorderkwartier (HHNK) to a 3Di model. It was originally developed by Nelen & Schuurmans. Since then, Royal-Haskoning and HHNK made contributions. 

Originally this modelbuilder ran in docker, but has been transformed to work on Windows. There are still some LInux based relics in the code.

The code refers to several hard-coded paths within the HHNK environment. 

## Installation

This modelbuilder requires an installation of Pixi, PostgreSQL and POSTGIS Bundle.

1. Pull the latest code from this repository using git/GitHub desktop. and place in folder name 'code'.
2. Place another folder named data at the same level as the code folder. In it paste a folder with 'fixed data' and `input`. The `fixed_data` is available from HHNK.
3. Run `pixi shell`

## Usage
The recommended way to run the datachecker and modelbuilder is to use VS Code with Python and Jupyter extensions.

### To run the datachecker
1. Place DAMO export `DAMO.gpkg` in the input folder
2. Run `datachecker\datachecker_visual_studio.py`

Output is placed in `data\output\01_source_data`.

### To run the modelbuilder
The modelbuilder uses the data in the postgres database present at the time it is run. So make sure this contains your data. The datachecker loads the input into the postgres database and perform several data conversions required for the modelbuilder.

The input and datachecker output may contain data for several polders or any area larger than the area for which you require a model. The modelbuilder creates a subset from this data.

To run the modelbuilder:
1. Modify `modelbuilder\modelbuilder_visual_studio.py` in line 247 and add the polder_id (str) and polder_name (str). These polder_id must match the `polder` layer in the input. The standard list is given below.
2. Run the script.

Output is placed in `data\output\01_schematisation`.

The modelbuilder has to be initialized with 2 variables, the `polder_id` and the `polder_name`. The `polder_id` is used to select data from the datachecker within the polder which id you supply, the `polder_name` is used in the output filenames (`.sqlite`, `.tif`). To run the modelbuilder use for example `python /code/modelbuilder/modelbuilder.py 15 starnmeer` from within the container or start the container like this `python /code/modelbuilder/modelbuilder.py 15 starnmeer`

## Data
If you don't specify any location for the input, output and fixed data it will bind the `data` directory within your github folder on your PC.
Make sure that the folder exists with at least the following data:

```bash
data
├───fixed_data
│   ├───datamining_ahn3
│   ├───hydroobjectid
└───input
    ├───DAMO.gpkg
```


## Database

To connect to the postgis database use the following settings:

	host: localhost
	port: 55550
	database: datachecker
	username: postgres
	password: "same as username"

## Standard area list

| ID | Naam                     | Code Polders V4                                                                                                                                                                                                                 |
|----|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1  | Heerhugowaard            | "03150","03350"                                                                                                                                                                                                                 |
| 2  | Drieban                  | "6090"                                                                                                                                                                                                                          |
| 3  | Purmer                   | "5801","5802","5803"                                                                                                                                                                                                            |
| 4  | Grootlimmerpolder        | "04230","04290","04300"                                                                                                                                                                                                         |
| 5  | Koegras                  | "2060","2040","2010","20601"                                                                                                                                                                                                    |
| 6  | Marken                   | "5160"                                                                                                                                                                                                                          |
| 7  | HUB                      | "04310","04320","04541","04542"                                                                                                                                                                                                 |
| 8  | Beemster                 | "5400","5401"                                                                                                                                                                                                                   |
| 9  | VNK                      | "6750"                                                                                                                                                                                                                          |
| 10 | t Hoekje                 | "2020","2040"                                                                                                                                                                                                                   |
| 11 | Assendelft               | "04751","04752","04380"                                                                                                                                                                                                         |
| 12 | Grootslag                | "6700","6770","6780","6080"                                                                                                                                                                                                     |
| 13 | Heiloo                   | "04170","04650","04160","04200"                                                                                                                                                                                                 |
| 14 | Purmerend                | "5741","5742","5721","5722","5841","5842","5320"                                                                                                                                                                                |
| 15 | Starnmeer                | "04460"                                                                                                                                                                                                                         |
| 16 | Eijerland                | 8040,"8071"                                                                                                                                                                                                                     |
| 17 | Mijzen                   | "04520"                                                                                                                                                                                                                         |
| 18 | Oudorp                   | "03765"                                                                                                                                                                                                                         |
| 20 | Wijdewormer              | "5310"                                                                                                                                                                                                                          |
| 21 | Noorderkaag              | "03703"                                                                                                                                                                                                                         |
| 23 | Edam Volendam Katwoude   | "5360","5781","5761","5762","5782"                                                                                                                                                                                              |
| 24 | VRNK-Oost                | "2100","2110","03190","03200","03210","6753"                                                                                                                                                                                    |
| 25 | Wieringermeer            | "7701","7702","7703","7704"                                                                                                                                                                                                     |
| 26 | Binnenduinrand Egmond    | "04100","04150","04902","04220","04902-00"                                                                                                                                                                                      |
| 27 | Geestmerambacht          | "03764","03751","03240","03801","03802","03763","03300","03752"                                                                                                                                                                 |
| 28 | Waterland                | "5170","5470","5821","5480","5230","5240","5560","5220","5180","5410","5250","5440","5500","5150","5510","5260","5520","5822","5200","5490","5210","5530","5540","5550","5570","5460","5600","5610","5620","5580","5390","5171" |
| 29 | Schermer                 | "04851","04852","04853"                                                                                                                                                                                                         |
| 30 | Zijpe-West               | "2751","2752","2775","2754","2780","2779","2050","2756"                                                                                                                                                                         |
| 31 | Oosterpolder Hoorn       | "6110","6100"                                                                                                                                                                                                                   |
| 32 | Westzaan                 | "04400","04390"                                                                                                                                                                                                                 |
| 33 | Bergermeer               | "04070","04080","04090","04952","04953","04640"                                                                                                                                                                                 |
| 34 | Wieringerwaard           | "2080"                                                                                                                                                                                                                          |
| 35 | Schagerkogge             | "03010","03020","03030","03040","03050","03060","03701","03702"                                                                                                                                                                 |
| 36 | Zeevang                  | "5701","5702","5703","5704","5705"                                                                                                                                                                                              |
| 37 | Westerkogge              | "6130"                                                                                                                                                                                                                          |
| 38 | Alkmaardermeerpolders    | "04250","04280","04260","04420","04270", "04240"                                                                                                                                                                                |
| 39 | Wieringen                | "2851","2852","2854","2855","2856"                                                                                                                                                                                              |
| 40 | Zijpe-Zuid               | "2757","2758","2759","2781","2763","2764","2765","2766"                                                                                                                                                                         |
| 41 | Egmondermeer             | "04130","04110","04951"                                                                                                                                                                                                         |
| 42 | Oostzaan                 | "5330","5340"                                                                                                                                                                                                                   |
| 43 | HOUW (Wohoobur)          | "6180","6190","6200","6210"                                                                                                                                                                                                     |
| 44 | Zijpe-Noord              | "2767","2768","2772","2769","2773","2774","2120"                                                                                                                                                                                |
| 45 | Callantsoog              | "2030","2040"                                                                                                                                                                                                                   |
| 46 | Bergen-Noord             | "04010","04020","04030","04040","04050","04060"                                                                                                                                                                                 |
| 47 | Berkmeer e.o.            | "6230","6240","03130","03140"                                                                                                                                                                                                   |
| 48 | Valkkoog en Schagerwaard | "03080","03090"                                                                                                                                                                                                                 |
| 49 | Waar Woud Spek eet       | "03100","03110","03120","03340"                                                                                                                                                                                                 |
| 50 | Wormer                   | "5270","5280","5290","5300"                                                                                                                                                                                                     |
| 51 | Eilandspolder            | "04801","04802","04803","04804","04470"                                                                                                                                                                                         |
| 53 | VRNK-West                | "03160","03170","03180","03070"                                                                                                                                                                                                 |
| 54 | Anna Paulowna            | "2803","2804","2805"                                                                                                                                                                                                            |
| 55 | NZK-polders              | "04340","04580","04590","04610","04410"                                                                                                                                                                                         |
| 56 | Beetskoog                | "5010","5020","5030","5040","5050","5080"                                                                                                                                                                                       |
| 57 | Texel-Zuid               | "8010","8020","8030","8071"                                                                                                                                                                                                     |
import datetime
import io
import re
import json
import argparse
import os
import sqlite3
import sys
import threading
import xml.etree.ElementTree as ET
import urllib.request

from typing import List
import subprocess
import time
import GamesDb
import re
from datetime import datetime, timedelta
import concurrent.futures

class CmdException(Exception):
    pass

class Amazon(GamesDb.GamesDb):
    #Variabile da linux che ha sorgente sul file settings.sh
    nile_cmd = os.path.expanduser(os.environ['NILE'])


    def __init__(self, db_file, storeName, setNameConfig=None):
        super().__init__(db_file, storeName=storeName,  setNameConfig=setNameConfig)
        self.storeURL = "https://gaming.amazon.com/"


    def execute_shell(self, cmd):
        print(f"cmd: {cmd}", file=sys.stderr)
        result = subprocess.Popen(cmd, stdout=subprocess.PIPE, stdin=subprocess.PIPE,
                                  stderr=subprocess.PIPE,
                                  shell=True).communicate()[0].decode()
        if "[cli] ERROR:" in result:
            raise CmdException(result)
        print(f" result: {result}", file=sys.stderr)
        try:
            json_result = json.loads(result)
            # print(f"json_result: {json_result}", file=sys.stderr)
            return json_result
        except json.JSONDecodeError:
            # Handle the case when the result is not valid JSON
            json_result = {"text": result}
            return json_result


    def get_list(self,  offline):
        offline_switch = "--offline" if offline else ""
        games_list = self.execute_shell(os.path.expanduser(f"{self.nile_cmd} library list -j"))
        id_list = []
        game_dict = {}
        for game in games_list:
            print(f"game: {game}", file=sys.stderr)
            shortname = game["product"]["id"]
            name = game["product"]["title"]
            game_dict.update({shortname: name})
            id_list.append(shortname)

        left_overs = self.insert_data(id_list)
        print(f"Left overs: {left_overs}", file=sys.stderr)

        for game in left_overs:
            print(f"game: {game}", file=sys.stderr)
            conn = self.get_connection()
            c = conn.cursor()
            c.execute("select id from Game where ShortName=?", (game,))
            result = c.fetchone()
            game_id = 0
            if result:
                game_id = result[0]
            else:    
                c.execute("Insert into Game (ShortName) VALUES (?)", (game,))
                game_id = c.lastrowid
                conn.commit()
            conn.close()
            print(f"updating game id: {game_id}", file=sys.stderr)
            gamename = game_dict[game]
            self.update_game_details(game_id, gamename, False) 


    #def get_game_json(self, game_name, offline):
    #    plugin_data_dir= os.path.expanduser( os.environ['DECKY_PLUGIN_RUNTIME_DIR'])
    #    tmp_dir = os.path.join(plugin_data_dir, "tmp")
    #    if not os.path.exists(tmp_dir):
    #        os.makedirs(tmp_dir)
    #    games_list = self.execute_shell(os.path.expanduser(f"{self.nile_cmd} --download --exclude all --save-product-json --game {game_name} --directory \"{tmp_dir}\""))
    #    product_file = os.path.join(tmp_dir, game_name, "product.json")
    #    product_data = {}
    #    with open(product_file, 'r') as f:
    #        product_data = json.load(f)
    #    return product_data


    def get_working_dir(self, game_id, offline):
        self.get_directory(offline, game_id, 'working_directory')

    def get_game_dir(self, game_id, offline):
        self.get_directory(offline, game_id, 'game_directory')

    def get_directory(self, offline, game_id, type):
        offline_switch = "--offline" if offline else ""
        result = self.execute_shell(os.path.expanduser(f"{self.nile_cmd} launch {game_id} --json {offline_switch}"))
        print(result[type])


    def get_login_status(self, offline, flush_cache=False):
        offline_switch = "--offline" if offline else ""
        cache_key = "amazon-login"
        if offline:
            cache_key = "amazon-login-offline"
        if(flush_cache):
            self.clear_cache(cache_key)

        cache = self.get_cache(cache_key)
        if cache is not None and not flush_cache:
            return cache

        result = self.execute_shell(os.path.expanduser(f"{self.nile_cmd} auth -s"))
        account = result["Username"]

        if offline:
            account += " (offline)"

        logged_in = account != "<not logged in>"
        value = json.dumps({'Type': 'LoginStatus', 'Content': {'Username': account, 'LoggedIn': logged_in}})
        timeout = datetime.now() + timedelta(hours=1)
        self.add_cache(cache_key, value, timeout)
        return value


    def get_parameters(self, game_id, offline):
        conn = self.get_connection()
        c = conn.cursor()
        c.row_factory = sqlite3.Row
        c.execute("SELECT Arguments FROM Game WHERE ShortName=?", (game_id,))
        result = c.fetchone()
        arguments = result['Arguments'].replace("\\", "/").replace("\"","") #.replace("-noconsole","").replace("\"exit\"","")
        print(f"Arguments: {arguments}", file=sys.stderr)
        conn.close()
        return arguments


    #non c'è nessun metodo di controllo tramite json con nile, ma è possibile usare nile list-updates
    #def has_updates(self, game_id, offline):
    #    offline_switch = "--offline" if offline else ""
    #    result = self.execute_shell(os.path.expanduser(
    #        f"{self.nile_cmd} info {game_id} --json {offline_switch}"))
    #    json_result = json.loads(result)
    #    if json_result['game']['version'] != json_result['install']['version']:
    #        return json.dumps({'Type': 'UpdateAvailable', 'Content': True})
    #    return json.dumps({'Type': 'UpdateAvailable', 'Content': False})
    

    def get_lauch_options(self, game_id, steam_command, name, offline):
        print(f"game_id: {game_id}", file=sys.stderr)
        print(f"steam_command: {steam_command}", file=sys.stderr)
        print(f"name: {name}", file=sys.stderr)
        offline_switch = "--offline" if offline else ""
        launcher = os.environ['LAUNCHER']
        conn = self.get_connection()
        c = conn.cursor()
        c.row_factory = sqlite3.Row
        c.execute("SELECT ApplicationPath, RootFolder, WorkingDir FROM Game WHERE ShortName=?", (game_id,))
        game = c.fetchone()
        install_dir = os.environ['INSTALL_DIR']
        root_dir = os.path.join(install_dir, game['RootFolder'])
        working_dir = os.path.join(root_dir, game['WorkingDir']).replace("\\","/")
        script_path = os.path.expanduser(launcher)
        print(f"script_path: {script_path}", file=sys.stderr)
        print(f"root_dir: {root_dir}", file=sys.stderr)
        game_exe = os.path.join(root_dir, game['ApplicationPath']).replace("\\","/")
        print(f"game: {game_exe}", file=sys.stderr)
        

        return json.dumps(
            {
                'Type': 'LaunchOptions',
                'Content':
                {
                    'Exe': f"\"{game_exe}\"",
                    'Options': f"{script_path} {game_id}%command%",
                    'WorkingDir': f"\"{working_dir}\"",
                    'Compatibility': True,
                    'Name': name
                }
            })


    #def update_game_details(self, game_id, shortname, offline):
    #    print(f"Updating game details for: {shortname}", file=sys.stderr)
    #    conn = self.get_connection()
    #    c = conn.cursor()
    #    game_json = self.get_game_json(shortname, offline)
    #    sort_order = {
    #        'logo': 1,
    #        'background1': 2,
    #        'background2': 3,
    #        'icon': 4
    #    }
    #    product = game_json.get("product", {})
    #    product_detail = product.get("productDetail", {})
    #    details = product_detail.get("details", {})
#
    #    # Mapping dei campi immagini con chiavi coerenti
    #    image_fields = {
    #        "logo": details.get("logoUrl"),
    #        "background1": details.get("backgroundUrl1"),
    #        "background2": details.get("backgroundUrl2"),
    #        "icon": product_detail.get("iconUrl")
    #    }
    #    for key, value in image_fields.items():
    #        if value:
    #            c.execute(
    #                "INSERT INTO Images (GameID, ImagePath, sortOrder) VALUES (?, ?, ?)", (game_id, value, sort_order[key]))
    #            conn.commit()
    #        description = game_json['description']['full']
    #        installers = game_json['downloads']['installers']
    #        for installer in installers:
    #            if installer['language'] == 'en' and installer['os'] == 'windows':
    #                size = installer['total_size']
    #                size = self.convert_bytes(size)
    #                c.execute(
    #                    "UPDATE Game SET Size=? WHERE id=?", (size, game_id))
    #                conn.commit()
    #                break
    #        c.execute(
    #            "UPDATE Game SET Notes=? WHERE id=?", 
    #            (description, game_id))
    #        conn.commit()


    #def add_missing_info(self):
    #    conn = self.get_connection()
    #    c = conn.cursor()
    #    c.execute("SELECT id, shortname FROM Game WHERE id NOT IN (SELECT DISTINCT gameid FROM Images)")
    #    games = c.fetchall()
    #    def process_game(game):
    #        game_id = game[0]
    #        shortname = game[1]
    #        self.update_game_details(game_id, shortname, False) 
    #    with concurrent.futures.ThreadPoolExecutor(max_workers=40) as executor:
    #        executor.map(process_game, games)
    #    conn.close()


    #def insert_game(self, game):
    #    conn = self.get_connection()
    #    c = conn.cursor()


    def convert_bytes(self , size):
        if size >= 1024**3:
            size = f"{size / 1024**3:.2f} GB"
        elif size >= 1024**2:
            size = f"{size / 1024**2:.2f} MB"
        elif size >= 1024:
            size = f"{size / 1024:.2f} KB"
        else:
            size = f"{size} bytes"
        return size


    # INFO [PROGRESS]:	 = Progress: 8.92 30317473/322598318, Running for: 00:00:16, ETA: 00:02:43
    # INFO [PROGRESS]:	 = Downloaded: 28.91 MiB, Written: 28.91 MiB
    # INFO [PROGRESS]:	  + Download	- 1.47 MiB/s
    # INFO [PROGRESS]:	  + Disk	- 1.47 MiB/s


    def calculate_total_size(self, progress_percentage, written_size):
        return round(written_size * (progress_percentage / 100), 2)


    #def get_game_dbid(self, shortname):
    #    conn = self.get_connection()
    #    c = conn.cursor()
    #    c.execute("SELECT DatabaseID FROM Game WHERE ShortName=?", (shortname,))
    #    result = c.fetchone()
    #    conn.close()
    #    return result[0]


    def get_last_progress_update(self, file_path):
        progress_re = re.compile(
            r"= Progress: ([\d.]+) (\d+)/(\d+), Running for: (\d+:\d+:\d+), ETA: (\d+:\d+:\d+)"
        )
        downloaded_re = re.compile(
            r"= Downloaded: ([\d.]+) MiB, Written: ([\d.]+) MiB"
        )
        speed_re = re.compile(
            r"\+ Download\s*- ([\d.]+) (.*/s)"
        )
        last_progress_update = None
        total_dl_size = None
        speed = "0.0"
        try:
            with open(file_path, "r") as f:
                lines = f.readlines()

            # Variabili temporanee per ogni blocco
            percent = current = total = downloaded = written = None
            for i in range(len(lines)):
                line = lines[i]
                if match := progress_re.search(line):
                    percent = float(match.group(1))
                    current = int(match.group(2))
                    total = int(match.group(3))
                    if percent == 100:
                        percent = 99
                    if current == total:
                        percent = 100
                elif match := downloaded_re.search(line):
                    downloaded = float(match.group(1))
                    written = float(match.group(2))
                elif match := speed_re.search(line):
                    speed = f"{round(float(match.group(1)), 2)} {match.group(2)}"

                # se abbiamo tutto, aggiorna
                if all(v is not None for v in [percent, current, total, downloaded, written]):
                    last_progress_update = {
                        "Percentage": round(percent),
                        "Description": f"Downloaded {self.convert_bytes(downloaded)}/{self.convert_bytes(total)}"
                                       f" ({round(percent)}%)\nSpeed: {speed}"
                    }

            # controlli finali
            if lines and "Download complete" in lines[-1]:
                last_progress_update = {
                    "Percentage": 100,
                    "Description": "Download complete"
                }

            if last_progress_update is None:
                last_progress_update = {
                    "Percentage": 0,
                    "Description": lines[-1].strip()
                }

        except Exception as e:
            print("Waiting for progress update", e, file=sys.stderr)
            time.sleep(1)

        return json.dumps({'Type': 'ProgressUpdate', 'Content': last_progress_update})


    def get_proton_command(self, cmd):
        match = re.search(r'waitforexitandrun -- (.*?) waitforexitandrun', cmd)
        if match:
            proton_cmd = match.group(1)
            sanitized_path = proton_cmd.replace('"', '').replace('\'', '')
            return sanitized_path
        else:
            return ""


    #def process_info_file(self, file_path):
    #    print(f"Processing info file: {file_path}", file=sys.stderr)
    #    conn = self.get_connection()
    #    c = conn.cursor()
    #    file_path = os.path.join(os.environ['INSTALL_DIR'], file_path)
    #    with open(file_path, 'r') as f:
    #        data = json.load(f)
    #        exe_file = ""
    #        args = ""
    #        working_dir = ""
    #        for task in data['playTasks']:
    #            if task['category'] == 'game':
    #                exe_file = task['path']
    #                if task.get('arguments'):
    #                    args = task['arguments']
    #                if task.get('workingDir'):
    #                    working_dir = task['workingDir']
    #                break
    #        print(f"Exe file: {exe_file}", file=sys.stderr)
    #        root_dir = os.path.abspath( os.path.dirname(file_path))
    #        print(f"Root dir: {root_dir}", file=sys.stderr)
    #        game_id = data['gameId']
    #        print(f"Game id: {game_id}", file=sys.stderr)
    #        c.execute("update Game set ApplicationPath = ?, RootFolder = ?, Arguments =?, WorkingDir =? where DatabaseID = ?", (exe_file, root_dir, args, working_dir, game_id))
    #        conn.commit()
    #    conn.close()


    def get_game_size(self, game_id, installed):
        if installed == 'true':
            conn = self.get_connection()
            c = conn.cursor()
            c.row_factory = sqlite3.Row
            c.execute("SELECT Size FROM Game WHERE ShortName=?", (game_id,))
            result = c.fetchone()
            conn.close()
            if result and bool(result['Size']):
                disk_size = result['Size']
                size = f"Size on Disk: {disk_size}"
            else:
                size = ""
        else:
            result = self.execute_shell(os.path.expanduser(f"{self.nile_cmd} install --info {game_id} --json"))
            manifest = result if isinstance(result, dict) else {}
            disk_size_val = manifest.get('disk_size')
            download_size_val = manifest.get('download_size')

            disk_size_str = f"Install Size: {self.convert_bytes(disk_size_val)}" if disk_size_val else ""
            download_size_str = f"Download Size: {self.convert_bytes(download_size_val)}" if download_size_val else ""

            size = disk_size_str + (f" ({download_size_str})" if download_size_str else "") if disk_size_str else download_size_str

        return json.dumps({'Type': 'GameSize', 'Content': {'Size': size}})

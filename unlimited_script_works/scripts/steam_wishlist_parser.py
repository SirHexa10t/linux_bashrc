#!/usr/bin/python3

"""
Find what those "unavailable" apps in your wishlist used to be
You need to provide a relevant work file. Don't worry, just run the program, it'll tell you what to do.
"""

import os
import json
import requests
from bs4 import BeautifulSoup


WISHLIST_FILE = "my_steam_wishlist.txt"
APPS_STATUS_FILE = "wishlist_app_statuses.txt"
APPS_MISSING_FILE = "wishlist_unavailable_apps.txt"


def file_missing(filename):
    return not os.path.exists(filename) or os.stat(filename).st_size == 0

def get_wishlist_content():
    try:
        with open(WISHLIST_FILE, "r") as file:
            return json.load(file).get('rgWishlist', [])
            
    except FileNotFoundError:
        print(f"Couldn't find '{WISHLIST_FILE}' in current directory. Please create and paste your wishlist app-IDs json into it: https://store.steampowered.com/dynamicstore/userdata/")
    except json.JSONDecodeError:
        print(f"'{WISHLIST_FILE}' isn't proper json. Populate it with the contents of your wishlist, as can be found here: https://store.steampowered.com/dynamicstore/userdata/")

def query_steam():
    ids = get_wishlist_content()
    url = f"https://store.steampowered.com/api/appdetails/?appids={','.join(map(str, ids))}&filters=price_overview"  # filters arg is required for this request to work

    print("QUERYING ALL WISHLIST APP STATUSES. Query:")
    print(url)

    response = requests.get(url)  # GET request
    response.raise_for_status()
    with open(APPS_STATUS_FILE, 'w') as file:
        file.write(response.text)
    print(f"Response saved to {APPS_STATUS_FILE}")
    


def find_problematic_apps():
    if file_missing(APPS_STATUS_FILE):  # needed file doesn't exist, write it
        query_steam()

    with open(APPS_STATUS_FILE, 'r') as file:
        unavailable_apps = [app_id for app_id, details in json.load(file).items() if details.get('success') is False]
        
    # write the app-ids into a file, each in its own line
    with open(APPS_MISSING_FILE, 'w') as file:
        file.writelines(f"{app_id}\n" for app_id in unavailable_apps)


def fetch_app_data(app_id):
    url = f"https://completionist.me/steam/app/{app_id}"
    response = requests.get(url)
    response.raise_for_status()
    
    soup = BeautifulSoup(response.text, 'html.parser')
    data_table = soup.find('div', class_='widget-body').find('dl', class_='dl-horizontal dl-sm')
    
    if not data_table:
        return f"{app_id}    completionist.me data not found or structure changed. Check manually at: https://completionist.me/steam/app/{app_id}"

    data = {}
    for key in ["Title", "Developer", "Publisher", "Tags"]:  # setting default no-data values now, to preserve order at the end of the run
        data.setdefault(key, "N/A" if key != "Tags" else [])

    for dt, dd in zip(data_table.find_all('dt'), data_table.find_all('dd')):
        label = dd.text.strip()
        if label == "Title":
            data[label] = dt.text.strip()
        elif label in ["Developer", "Publisher"]:
            data[label] = dt.find('a').text.strip() if dt.find('a') else "N/A"
        elif label == "Genres":
            data["Tags"] = [genre.strip() for genre in dt.text.strip().split(',')] if dt.text.strip() else []

    print(f"found data for app {app_id}")
    return f"{app_id}    completionist.me data: {data}"



def find_app_names():
    if file_missing(APPS_MISSING_FILE):  # needed file doesn't exist, write it
        find_problematic_apps()

    # get the app names from SteamDB
    updated_lines = []
    with open(APPS_MISSING_FILE, 'r') as file:
        for line in file:
            line = line.strip()
            if line.isdigit():  # Process just the lines that contain only a number
                app_id = line
                
                try:
                    data_line = fetch_app_data(app_id)
                    updated_lines.append(f"{data_line}\n")
                except requests.RequestException as e:
                    print(f"Failed to fetch data for app ID {app_id}: {e}")
                    updated_lines.append(f"{app_id}\n")  # Leave the line as-is
            else:
                updated_lines.append(line + '\n')  # Preserve non-numeric lines

    # Write updated lines back to the file
    with open(APPS_MISSING_FILE, 'w') as file:
        file.writelines(updated_lines)
        print(f"Wrote/updated file: '{APPS_MISSING_FILE}'. You should find there games that were removed from Steam or blocked from your region.")


def main():
    find_app_names()


if __name__ == "__main__":
    main()

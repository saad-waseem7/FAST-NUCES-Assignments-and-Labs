from selenium import webdriver
from selenium.webdriver.common.by import By
import pandas as pd
import time

driver = webdriver.Chrome()

url = "https://en.wikipedia.org/wiki/List_of_countries_by_GDP_(nominal)"
driver.get(url)
time.sleep(3) 

print("Page Title:", driver.title)
table = driver.find_element(By.CSS_SELECTOR, "table.wikitable")

headers = [th.text.strip() for th in table.find_elements(By.TAG_NAME, "th")]
rows = table.find_elements(By.TAG_NAME, "tr")

data = []
for row in rows[1:]:
    cols = row.find_elements(By.TAG_NAME, "td")
    if len(cols) == 0:
        continue
    data.append([col.text.strip() for col in cols])

df = pd.DataFrame(data, columns=headers[1:len(data[0])+1]) 

csv_file = "countries_by_GDP_nominal.csv"
df.to_csv(csv_file, index=False)

print(f"Data saved to {csv_file}")

driver.quit()

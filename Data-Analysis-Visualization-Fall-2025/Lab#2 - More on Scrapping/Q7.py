from selenium import webdriver
from selenium.webdriver.common.by import By
import pandas as pd
import time

driver = webdriver.Chrome()

url = "https://www.w3schools.com/tags/tryit.asp?filename=tryhtml_button_test"
driver.get(url)
time.sleep(2) 

driver.switch_to.frame("iframeResult")
buttons = driver.find_elements(By.TAG_NAME, "button")

data = []
for button in buttons:
    text = button.text
    link = button.get_attribute("onclick") or button.get_attribute("formaction")
    data.append({"Button Text": text, "Link/Action": link})

df = pd.DataFrame(data)
print(df)

df.to_csv("buttons.csv", index=False)

driver.quit()

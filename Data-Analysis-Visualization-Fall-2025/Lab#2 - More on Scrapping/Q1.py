from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
import time


driver = webdriver.Chrome()
driver.get('https://www.bing.com/')
time.sleep(5) 

search_box = driver.find_element(By.ID, "sb_form_q")
search_box.send_keys("Python programming")
search_box.send_keys(Keys.RETURN)  

time.sleep(5) 
titles = driver.find_elements(By.TAG_NAME, "h2")

print("\nTop Results:\n")
for i, title in enumerate(titles[:5]):
    print(f"{i + 1}. {title.text}")

driver.quit()
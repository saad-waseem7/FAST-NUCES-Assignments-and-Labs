from selenium import webdriver
from selenium.webdriver.common.by import By
import time


driver = webdriver.Chrome()

driver.get("https://quotes.toscrape.com")
time.sleep(2) 

quotes = driver.find_elements(By.CSS_SELECTOR, "span.text")
authors = driver.find_elements(By.CSS_SELECTOR, "small.author")

for i in range(len(quotes)):
    print(f"{i+1}. {quotes[i].text} — {authors[i].text}")

driver.quit()

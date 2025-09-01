from selenium import webdriver
from selenium.webdriver.common.by import By
import time

driver = webdriver.Chrome()

driver.get("https://books.toscrape.com/")
time.sleep(2)

books = driver.find_elements(By.CSS_SELECTOR, "article.product_pod")

for i, book in enumerate(books, start=1):
    title = book.find_element(By.TAG_NAME, "h3").find_element(By.TAG_NAME, "a").get_attribute("title")
    price = book.find_element(By.CSS_SELECTOR, ".price_color").text
    availability = book.find_element(By.CSS_SELECTOR, ".availability").text.strip()
    print(f"{i}. {title} | {price} | {availability}")

driver.quit()

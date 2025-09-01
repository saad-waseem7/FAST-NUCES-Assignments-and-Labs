from selenium import webdriver
from selenium.webdriver.common.by import By
import time

driver = webdriver.Chrome()

url = "https://books.toscrape.com/catalogue/category/books/science_22/index.html"
driver.get(url)
time.sleep(2)  

driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
time.sleep(2) 

books = driver.find_elements(By.CSS_SELECTOR, "article.product_pod h3 a")

print("Science Books Found:")
for i, book in enumerate(books, start=1):
    title = book.get_attribute("title")
    print(f"{i}. {title}")

driver.quit()

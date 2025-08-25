from selenium import webdriver
from selenium.webdriver.common.by import By
import time

# Create a Chrome browser instance
driver = webdriver.Chrome()
driver.get("https://books.toscrape.com/")

time.sleep(2)

# Find and click the Travel link
travel_link = driver.find_element(By.LINK_TEXT, "Travel")
travel_link.click()

time.sleep(2)

# Find all book titles
books = driver.find_elements(By.CSS_SELECTOR, "h3 a")

# Print each book title
print("Travel Books Found:")
for book in books:
    print(book.text)
    
driver.quit()

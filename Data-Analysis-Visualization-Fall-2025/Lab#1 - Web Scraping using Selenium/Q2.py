from selenium import webdriver
from selenium.webdriver.common.by import By
import csv

driver = webdriver.Chrome()
driver.get("https://books.toscrape.com/")  # Open demo e-commerce site

# Locate all book product containers on the page
books = driver.find_elements(By.CSS_SELECTOR, "article.product_pod")

# Open a CSV file to write scraped data
with open("books.csv", mode="w", newline="", encoding="utf-8") as file:
    writer = csv.writer(file)
    writer.writerow(["Title", "Price"])  # Write header

    for book in books:
        title = book.find_element(By.TAG_NAME, "h3").text
        price = book.find_element(By.CLASS_NAME, "price_color").text
        writer.writerow([title, price])
        print(f"Found Book: {title} - {price}")

driver.quit()

print("\nAll done! Your data has been saved to books.csv")

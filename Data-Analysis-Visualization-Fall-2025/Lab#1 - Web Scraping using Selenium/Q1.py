from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import time

# Initialize the Chrome driver with options
options = Options()
options.add_argument("--headless")  # Run in headless mode (optional)
driver = webdriver.Chrome(options=options)
driver.get("https://www.google.com")

# Find the search box, enter the keyword, and submit
search_box = driver.find_element(By.NAME, "q")
search_box.send_keys("Python programming")
search_box.submit()

# Wait for a shorter time, 5 seconds should be enough
time.sleep(5)

titles = driver.find_elements(By.TAG_NAME, "h3")
print("\nTop Results:\n")

for i, title in enumerate(titles[:10]):
    print(f"{i + 1}. {title.text}")

# Close the browser
driver.quit()

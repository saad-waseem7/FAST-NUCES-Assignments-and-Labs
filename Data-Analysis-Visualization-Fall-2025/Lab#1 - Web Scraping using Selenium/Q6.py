from selenium import webdriver
from selenium.webdriver.common.by import By
import os
import requests

# Initialize the Chrome driver
driver = webdriver.Chrome()
driver.get("https://books.toscrape.com/")

images = driver.find_elements(By.TAG_NAME, "img")

img_urls = [img.get_attribute("src") for img in images[:5]]
print("Image URLs Found:")
for url in img_urls:
    print(url)

os.makedirs("downloaded_images", exist_ok=True)  # Create folder for images

for idx, url in enumerate(img_urls, start=1):
    response = requests.get(url)  # Fetch image data
    with open(f"downloaded_images/image_{idx}.jpg", "wb") as f:
        f.write(response.content)  # Save as jpg file
    print(f"Downloaded image_{idx}.jpg")

import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("books.csv")
df.drop_duplicates(inplace=True)
df.fillna("N/A", inplace=True)
df["Price"] = df["Price"].str.replace("£", "", regex=False)
df["Price"] = pd.to_numeric(df["Price"], errors="coerce")
print("Average Price:", df["Price"].mean())
print("Max Price:", df["Price"].max())
print("Min Price:", df["Price"].min())

df["Time"] = range(1, len(df) + 1)
plt.figure(figsize=(10,5))
plt.plot(df["Time"], df["Price"], marker="o", linestyle="-", color="b")
plt.xlabel("Time (Index)")
plt.ylabel("Price (£)")
plt.title("Price Trend of Books")
plt.show()

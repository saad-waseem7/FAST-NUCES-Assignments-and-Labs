import pandas as pd
import numpy as np

df = pd.read_csv("books.csv")
print(df)
df["Price"] = df["Price"].str.replace("£", "", regex=False)  # Remove '£'
df["Price"] = pd.to_numeric(df["Price"], errors="coerce")  # Convert to numbers

print(df)

df.mean()
df.median()
df.mode()

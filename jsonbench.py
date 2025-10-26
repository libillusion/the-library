import json
import random
import time

# --- Configuration ---
NUM_USERS = 500  # Target: 10,000 user records for a large file
FILENAME = "benchmarking_data.json"
# ---------------------


# Helper function to generate a random address
def generate_random_address():
    streets = ["Main St", "Oak Ave", "Pine Ln", "Elm Blvd", "Cedar Rd"]
    cities = ["Metropolis", "Gotham", "Star City", "Central City", "Smallville"]
    states = ["NY", "CA", "TX", "FL", "IL"]
    return {
        "street": f"{random.randint(100, 999)} {random.choice(streets)}",
        "city": random.choice(cities),
        "state": random.choice(states),
        "zipCode": str(random.randint(10000, 99999)),
    }


# Helper function to generate random order items
def generate_order_items():
    num_items = random.randint(1, 5)
    items = []
    products = ["Laptop", "Monitor", "Keyboard", "Mouse", "Webcam", "Headset"]
    for i in range(num_items):
        price = round(random.uniform(10.0, 1500.0), 2)
        quantity = random.randint(1, 3)
        items.append(
            {
                "productName": f"{random.choice(products)} {i + 1}",
                "quantity": quantity,
                "unitPrice": price,
            }
        )
    return items


# Helper function to generate a random order
def generate_random_order(user_id):
    items = generate_order_items()
    total = round(sum(item["quantity"] * item["unitPrice"] for item in items), 2)
    return {
        "orderId": f"ORD-{user_id}-{random.randint(100000, 999999)}",
        "orderDate": time.strftime(
            "%Y-%m-%dT%H:%M:%SZ",
            time.gmtime(time.time() - random.randint(86400, 31536000)),
        ),  # Last year
        "totalAmount": total,
        "items": items,
    }


# Main function to generate a user record
def generate_user_record(user_id):
    first_name = f"UserFirst{user_id}"
    last_name = f"UserLast{user_id}"
    num_orders = random.randint(0, 5)

    return {
        "id": user_id,
        "username": f"{first_name.lower()}.{last_name.lower()}",
        "email": f"{first_name.lower()}{user_id}@example.com",
        "isActive": random.choice([True, False]),
        "profile": {
            "firstName": first_name,
            "lastName": last_name,
            "age": random.randint(18, 75),
            "address": generate_random_address(),
        },
        "orders": [generate_random_order(user_id) for _ in range(num_orders)],
        "tags": random.sample(
            ["VIP", "New", "Loyal", "Inactive", "High-Value"], k=random.randint(0, 3)
        ),
    }


# --- Generation and Writing ---
print(f"Starting generation of {NUM_USERS} records...")
start_time = time.time()

# Generate all data in memory first
data = [generate_user_record(i) for i in range(1, NUM_USERS + 1)]

print(
    f"Data generated in {time.time() - start_time:.2f} seconds. Starting file write..."
)

# Write the data to a JSON file
try:
    with open(FILENAME, "w") as f:
        # Use simple 'separators' to minimize file size (less whitespace/formatting)
        # For readability, you could remove the separators argument, but it makes the file larger.
        json.dump(data, f, indent=None, separators=(",", ":"))

    # Using 'indent=4' for readability would create a file that's significantly larger
    # with open(FILENAME, 'w') as f:
    #     json.dump(data, f, indent=4) # Use this if you need a human-readable file

    print(f"\n✅ Successfully created '{FILENAME}' with {NUM_USERS} records.")
    print("The file is ready for benchmarking.")
except Exception as e:
    print(f"\n❌ An error occurred during file writing: {e}")

import bcrypt
hash = bcrypt.hashpw(b"Admin123*", bcrypt.gensalt()).decode()
print(hash)

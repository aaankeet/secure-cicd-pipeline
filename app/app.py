# Vulnerable App for testing
user_input = input("Enter expression: ")
result = eval(user_input)  # this should trigger no-eval rule
print(result)

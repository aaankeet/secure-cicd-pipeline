# # Vulnerable App for testing
# # This Should fail, Do not use this in production
#
# user_input = input("Enter expression: ")
# result = eval(user_input)  # this should trigger no-eval rule
# print(result)


# Fixed Version
def calculate(user_input):
    return int(user_input)

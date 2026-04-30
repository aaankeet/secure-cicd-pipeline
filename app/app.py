# Simple vulnerable app
def calculate(user_input):
    # ❌ Vulnerable: eval() executes arbitrary code
    result = eval(user_input)
    return result

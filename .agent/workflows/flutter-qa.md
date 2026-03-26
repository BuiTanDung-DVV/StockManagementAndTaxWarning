---
description: Scaffold a new Flutter feature using Clean Architecture principles
---

# Workflow: New Flutter Feature Scaffold

## Trigger
Run this workflow when the user asks to "create a new feature," "add a page," or "scaffold a module."

## Step 1: Requirements Gathering
Ask the user for:
1.  **Feature Name:** (e.g., `user_profile`, `login`, `product_detail`)
2.  **State Management Preference:** (Riverpod, Bloc, or Provider?)
3.  **Complexity Level:** (Simple UI only, or Full Stack with API/Repo?)

## Step 2: Architecture Planning
Propose a folder structure based on the inputs. For a "Full Stack" feature, the structure should look like this:
lib/features/[feature_name]/
├── data/
│   ├── models/
│   └── repositories/
├── domain/
│   └── entities/
├── presentation/
│   ├── controllers/ (or blocs/)
│   └── widgets/
└── [feature_name]_screen.dart

## Step 3: Code Generation
Once the user confirms the structure:
1.  **Create the Model:** Use `json_serializable` or `freezed` syntax.
2.  **Create the Repository:** Define the interface in `domain` and implementation in `data`.
3.  **Create the Logic:** Create the Provider/Bloc to handle state.
4.  **Create the UI:** Create a `Scaffold` widget that listens to the state.

## Step 4: Integration
Remind the user to:
1.  Add the new route to the `GoRouter` or `routes.dart` file.
2.  Run `dart run build_runner build` if code generation was used.
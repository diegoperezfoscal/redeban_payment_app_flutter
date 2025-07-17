# redeban_payment_app

## Getting Started


### Installation

#### 1. Clone the repository

```bash
git clone [REPOSITORY_URL]
cd redeban_payment_app
```

#### 2. Set up environment variables

Create a `.env` file in the project root with the following variables:

```env
SERVER_APP_CODE=your_server_app_code_here
SERVER_APP_KEY=your_server_app_key_here
CLIENT_APP_CODE=your_client_app_code_here
CLIENT_APP_KEY=your_client_app_key_here
```


#### 3. Install Flutter dependencies

In the project root, run:

```bash
flutter pub get
```

#### 4. Install Android dependencies

Navigate to the android folder and run:

```bash
cd android
./gradlew build
```

Or if you're on Windows:

```bash
cd android
gradlew.bat build
```

#### 5. Run the application

Return to the project root and run:

```bash
flutter run
```

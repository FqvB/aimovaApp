from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.health import router as health_router
from routes.auth import router as auth_router
from routes.clubs import router as clubs_router
from routes.shots import router as shots_router
from routes.dispersion import router as dispersion_router
from routes.wind import router as wind_router

app = FastAPI(title="GolfApp API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(auth_router)
app.include_router(clubs_router)
app.include_router(shots_router)
app.include_router(dispersion_router)
app.include_router(wind_router)

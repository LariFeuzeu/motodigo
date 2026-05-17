from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

router = APIRouter()
templates = Jinja2Templates(directory="app/web/templates")


@router.get("/", response_class=HTMLResponse)
async def get_landing_page(request: Request):
    # C'est ici que tu passeras plus tard le nombre de chauffeurs/passagers
    return templates.TemplateResponse(
        "public/landing_page.html",
        {"request": request}
    )

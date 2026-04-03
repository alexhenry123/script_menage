# -------------------------------------- Assignation de variables --------------------------------------

# Choix d'encodage
$PSDefaultParameterValues["*:Encoding"] = "UTF8"

# Choisir ce que fait le script s'il y a une erreur
$ErrorActionPreference = "Stop"

# True : tester et voir quelles actions prendront le script
# False : exécuter les commandes du script 
$WhatIfPreference = $false


# -------------------------------------------- Fonctions --------------------------------------------


# Fonction pour journaliser les actions du script dans le fichier log
function Write-Log 
{
    param(
        [Parameter(Mandatory)]
        [string] $Contenu,

        [Parameter(Mandatory)]
        [ValidateSet("INFO", "AVERTISSEMENT", "ERREUR")]
        [string] $Sévérité
    )

    # Assignation des variables
    $fichier_logs = "C:\Scripts\Logs\journaux.log"
    $horodatage = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Si le fichier de logs et ses dossiers parents ne sont pas encore présents, les ajouter
    if (-not(Test-Path $fichier_logs)) {New-Item -ItemType File -Path $fichier_logs -Force}

    # Mettre le contenu des actions du script dans le fichier de journaux avec l'horodatage et la sévérité 
    Add-Content -Path $fichier_logs -Value "$($horodatage)   -   $($Sévérité)   -   $($Contenu)"
}

# Fonction 1 : Suppression des utilisateurs désuets
function Remove-Users 
{
    # SID des comptes systèmes et loaner qui ne doivent pas être supprimés
    $SID_loaner = "S-1-12-1-3684075938-1177419516-3185746318-4102645725"
    $SID_profil_systeme = "S-1-5-18"
    $SID_service_local = "S-1-5-19"
    $SID_service_reseau = "S-1-5-20"

    Write-Host "Suppression des utilisateurs en cours..." -ForegroundColor Cyan

    # Supprimer tous les utilisateurs qui sont ni système ni loaner
    Remove-CimInstance -Query "SELECT * FROM Win32_UserProfile 
    WHERE SID != '$($SID_loaner)' 
    AND SID != '$($SID_service_local)' 
    AND SID != '$($SID_service_reseau)' 
    AND SID != '$($SID_profil_systeme)'" 

    Write-Host "Les utilisateurs ont été supprimés avec succès" -ForegroundColor Green
    Write-Log -Sévérité "INFO" -Contenu "Les utilisateurs ont été supprimés avec succès"
}

# Fonction 2 : Automatisation des mises à jour Windows et redémarrage automatique 
function Get-Update 
{
    # Prérequis : installer le module PSWindowsUpdate pour mettre à jour le système (s'il n'est pas déjà installé)
    if (-not(Get-Module -ListAvailable -Name PSWindowsUpdate)) 
    {
        Write-Host "Installation du module PSWindowsUpdate afin de permettre les mises à jour sur PowerShell" -ForegroundColor Cyan
        Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope CurrentUser 

        Write-Host "Installation du module terminée" -ForegroundColor Green
        Write-Log -Sévérité "INFO" -Contenu "Installation du module terminée"
    }

    # Test de ping pour voir s'il y a un accès Internet. S'il échoue, demander au lanceur du script s'il désire toujours lancer les mises à jour Windows
    Write-Host "Test de ping pour vérifier l'accès à Internet" -ForegroundColor Cyan
    Write-Log -Sévérité "INFO" -Contenu "Test de ping pour vérifier l'accès à Internet"
    if (-not(Test-Connection google.com -Quiet))
    {
        $poursuivre_ou_non = (Read-Host "L'ordinateur n'est pas connecté à Internet. Désirez-vous tout de même poursuivre avec l'installation (Oui ou Non) ?").ToLower()
        # Si l'option "Non" est choisie, sortir du script 
        if ($poursuivre_ou_non -like "n*") 
        {            
            Write-Host "Le script a été arrêté par l'utilisateur" 
            Write-Log -Sévérité "INFO" -Contenu "Le script a été arrêté par l'utilisateur"
            exit
        }
        # Si l'option "Oui" est choisie, continuer le script
        elseif ($poursuivre_ou_non -like "o*") 
        {
            Write-Host "L'option 'oui' a été sélectionnée, le script se poursuit" 
            Write-Log -Sévérité "INFO" -Contenu "L'option 'oui' a été sélectionnée, le script continue"
        }
        # Si une réponse invalide est fournie, sortir du script
        else 
        {
            Write-Host "Le script n'a pas reconnu l'option choisie pour poursuivre les mises à jour, il s'est donc arrêté" 
            Write-Log -Sévérité "ERREUR" -Contenu "Le script n'a pas reconnu l'option choisie pour poursuivre les mises à jour, il s'est donc arrêté"
            exit
        }
    }
    
    # Vérifier s'il y a des mises à jour Windows à effectuer. S'il n'y en a pas, sortir de la fonction
    Write-Host "Vérification des mises à jour Windows à effectuer" -ForegroundColor Cyan
    Write-Log -Sévérité "INFO" -Contenu "Vérification des mises à jour Windows à effectuer"
    $mises_a_jour_disponibles = Get-WindowsUpdate
    if ($null -eq $mises_a_jour_disponibles) 
    {
        Write-Log -Sévérité "INFO" -Contenu "Aucune mise à jour Windows disponible pour l'instant. Sortie du script"
        Write-Host "Aucune mise à jour Windows disponible pour l'instant" -ForegroundColor Green
        return
    }

    # Automatiser le lancement des mises à jour Windows et le redémarrage du système pour terminer les mises à jour restantes
    Write-Host "Lancement des mises à jour Windows Update" -ForegroundColor Cyan
    Get-WindowsUpdate -Install -AcceptAll -AutoReboot -MicrosoftUpdate -RecurseCycle 10 

    Write-Host "Les mises à jour ont été installées avec succès" -ForegroundColor Green
    Write-Log -Sévérité "INFO" -Contenu "Les mises à jour ont été installées avec succès"
}

# Fonction 3 : Oublier tous les réseaux Wi-Fi connus 
function Remove-Network
{
    netsh.exe wlan delete profile name=* i=*
    Write-Host "Les réseaux Wi-Fi ont été oubliés avec succès" -ForegroundColor Green
    Write-Log -Sévérité "INFO" -Contenu "Les réseaux Wi-Fi ont été oubliés avec succès"
}



# -------------------------------------------- Code principal --------------------------------------------



# Afficher le texte demandant de choisir quelle(s) fonction(s) appeler 
Write-Host "
Entrez le chiffre correspondant à l'option choisie :

1. Supprimer les utilisateurs désuets, lancer les mises à jour Windows et oublier tous les réseaux Wi-Fi
2. Lancer les mises à jour Windows et oublier tous les réseaux Wi-Fi
3. Lancer les mises à jour Windows
"
# Lire le chiffre entré par le lanceur du script
$choix_lancement = Read-Host "Entrez ici votre choix (1 à 3) " 

# Exécuter les fonctions selon le chiffre entré par le lanceur du script
try 
{
    switch($choix_lancement)
    {
        "1" {Remove-Users ; Get-Update ; Remove-Network}
        "2" {Get-Update ; Remove-Network}
        "3" {Get-Update}
        default {Write-Host "Veuillez entrer un chiffre entre 1 et 3" -ForegroundColor Red}   
    }
}
catch 
{
    Write-Host "Une erreur est survenue : $_" -ForegroundColor Red
    Write-Log -Sévérité "ERREUR" -Contenu $_
}

﻿using System.Collections;
using RPG.Attributes;
using RPG.Control;
using UnityEngine;

namespace RPG.Combat
{
    public class WeaponPickup : MonoBehaviour, IRaycastable
    {
        [SerializeField] private WeaponConfig weaponConfig = null;
        [SerializeField] private float healthToRestore = 0f;
        [SerializeField] private float respawnTime = 5f;
        [SerializeField] private GameObject cube;

        private void Update()
        {
            // Rotate the cube over time
            Vector3 rotationDirection = new Vector3(0, 20, 0);
            cube.transform.Rotate(rotationDirection * Time.deltaTime);
        }

        private void OnTriggerEnter(Collider other)
        {
            // Player picks up the weapon pickup
            if (other.CompareTag("Player"))
            {
                Pickup(other.gameObject);
            }
        }

        private void Pickup(GameObject subject)
        {
            if (weaponConfig != null)
            {
                subject.GetComponent<Fighter>().EquipWeapon(weaponConfig);
            }

            if (healthToRestore > 0f)
            {
                subject.GetComponent<Health>().Heal(healthToRestore);
            }
            // Weapon pickup disappears for some time and respawns after
            StartCoroutine(HideForSeconds(respawnTime));
        }

        /// <summary>
        /// Disappear for some time and respawn
        /// </summary>
        /// <param name="seconds">Time to disappear for</param>
        /// <returns></returns>
        private IEnumerator HideForSeconds(float seconds)
        {
            ShowPickup(false);
            yield return new WaitForSeconds(seconds);
            ShowPickup(true);
        }

        /// <summary>
        /// Show or hide the weapon pickup based on bool that is passed in
        /// </summary>
        /// <param name="shouldShow">To show or to hide weapon pickup</param>
        private void ShowPickup(bool shouldShow)
        {
            GetComponent<Collider>().enabled = shouldShow;
            foreach (Transform child in transform)
            {
                // Disable all children
                child.gameObject.SetActive(shouldShow);
            }
        }

        public CursorType GetCursorType()
        {
            return CursorType.Pickup;
        }

        public bool HandleRaycast(PlayerController playerController)
        {
            if (Input.GetMouseButtonDown(0))
            {
                Pickup(playerController.gameObject);
            }

            return true;
        }
    }
}

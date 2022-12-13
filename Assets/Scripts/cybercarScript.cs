using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class cybercarScript : MonoBehaviour
{

    Rigidbody rb;

    // Start is called before the first frame update
    void Start()
    {
        rb = GetComponent<Rigidbody>();
    }

    // Update is called once per frame
    void FixedUpdate()
    {
        if (Input.GetKey("up")) {
            rb.AddForce(transform.forward * 10);
        }
        if (Input.GetKey("down")) {
            rb.AddForce(transform.forward * -10);
        }
        if (Input.GetKey("right")) {
            rb.AddTorque(transform.up * 2);
        }
        if (Input.GetKey("left")) {
            rb.AddTorque(transform.up * -2);
        }
    }
}

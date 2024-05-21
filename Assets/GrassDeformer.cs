using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GrassDeformer : MonoBehaviour
{
    public ModelGrass grass;

    public ModelGrass.GrassDeformerData data;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        data.uvPosition.x = (grass.transform.position.x - transform.position.x)/grass.resolution + 0.5f;
        data.uvPosition.y = (grass.transform.position.z - transform.position.z)/grass.resolution + 0.5f;
        grass.Deform(data);
    }
}
